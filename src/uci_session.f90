module uci_session
  use, intrinsic :: iso_fortran_env, only: int32, int64, real64, output_unit
  use pandatran, only: engine_name
  use chess_moves, only: max_moves, move_text, parse_move
  use chess_positions, only: position, undo_state, parse_fen, start_fen, make_move
  use chess_movegen, only: generate_legal, move_list
  use chess_draws, only: position_history, reset_history, record_game_position
  use chess_search, only: search_control, search_result, iterative_search, max_search_depth, mate_score, mate_threshold
  use uci_input, only: line_reader, line_ready, input_closed
  use uci_clock, only: search_budget, budget_for_move, stop_after_iteration
  implicit none
  private
  public :: run_uci

  type :: search_settings
    integer(int64) :: remaining(2) = -1, increment(2) = 0, movetime = -1
    integer(int64) :: nodes = huge(0_int64), moves_to_go = 24
    integer :: depth = max_search_depth
    logical :: infinite = .false., restrict_moves = .false.
    type(move_list) :: allowed
  end type search_settings

  type, extends(search_control) :: uci_control
    type(line_reader) :: input
    character(len=:), allocatable :: pending
    integer(int64) :: start_tick, tick_rate
    type(search_budget) :: budget
    real(real64) :: deadline, previous_elapsed
    integer(int64) :: previous_nodes, previous_iteration_nodes
    integer(int32) :: previous_move
    logical :: stopped = .false., exiting = .false.
  contains
    procedure :: cancelled
    procedure :: stop_after_depth => clock_limit_reached
  end type uci_control

contains

  subroutine run_uci(mode, profile)
    integer, intent(in), optional :: mode, profile
    type(uci_control) :: control
    type(position) :: pos
    type(position_history) :: history
    character(len=:), allocatable :: line, command
    integer :: status, cursor

    if (present(mode)) control%mode = mode
    if (present(profile)) control%evaluation = profile
    if (.not. parse_fen(start_fen, pos)) error stop 'Invalid built-in start position'
    call reset_history(pos, history)
    do while (.not. control%exiting)
      if (allocated(control%pending)) then
        call move_alloc(control%pending, line)
      else
        call control%input%read_line(-1, line, status)
        if (status == input_closed) exit
        if (status /= line_ready) cycle
      end if
      cursor = 1
      command = next_word(line, cursor)
      select case (command)
      case ('uci')
        call identify()
      case ('isready')
        call send_line('readyok')
      case ('ucinewgame')
        call control%table%clear()
        call reset_history(pos, history)
      case ('position')
        if (.not. set_position(line, cursor, pos, history)) call send_line('info string invalid position')
      case ('go')
        call play(line, cursor, pos, history, control)
      case ('quit')
        exit
      end select
    end do
  end subroutine run_uci

  subroutine play(line, cursor, pos, history, control)
    character(len=*), intent(in) :: line
    integer, intent(inout) :: cursor
    type(position), intent(inout) :: pos
    type(position_history), intent(inout) :: history
    type(uci_control), intent(inout) :: control
    type(search_settings) :: settings
    type(move_list) :: roots
    type(search_result) :: result
    character(len=5) :: reply

    if (.not. parse_go(line, cursor, settings)) then
      call send_line('info string invalid go')
      return
    end if
    call system_clock(count=control%start_tick, count_rate=control%tick_rate)
    control%budget = budget_for_move(settings%remaining(pos%turn), settings%increment(pos%turn), &
      settings%moves_to_go, settings%movetime, settings%infinite)
    control%deadline = control%budget%hard
    control%node_limit = settings%nodes
    control%stopped = .false.
    control%previous_elapsed = 0.0_real64
    control%previous_nodes = 0
    control%previous_iteration_nodes = 0
    control%previous_move = 0
    call generate_legal(pos, roots)
    if (settings%restrict_moves) call filter_roots(roots, settings%allowed)

    call iterative_search(pos, history, roots, settings%depth, control, result, report_depth)
    reply = '0000'
    if (result%move /= 0) reply = move_text(result%move)

    if (settings%infinite) then
      do while (.not. control%stopped)
        call service_search_input(control, -1)
      end do
    else
      if (.not. control%stopped) call service_search_input(control, 0)
    end if
    if (.not. control%exiting .and. .not. allocated(control%pending)) call send_line('bestmove ' // trim(reply))
  end subroutine play

  subroutine service_search_input(control, timeout)
    class(uci_control), intent(inout) :: control
    integer, intent(in) :: timeout
    character(len=:), allocatable :: line, command
    integer :: status, cursor

    do while (.not. control%stopped)
      call control%input%read_line(timeout, line, status)
      if (status == input_closed) then
        control%exiting = .true.
        control%stopped = .true.
        return
      end if
      if (status /= line_ready) return
      cursor = 1
      command = next_word(line, cursor)
      select case (command)
      case ('isready')
        call send_line('readyok')
      case ('uci')
        call identify()
      case ('stop')
        control%stopped = .true.
      case ('quit')
        control%exiting = .true.
        control%stopped = .true.
      case ('position', 'go', 'ucinewgame')
        call move_alloc(line, control%pending)
        control%stopped = .true.
      end select
    end do
  end subroutine service_search_input

  logical function cancelled(control) result(stopped)
    class(uci_control), intent(inout) :: control

    call service_search_input(control, 0)
    stopped = control%stopped
    if (stopped .or. control%deadline < 0.0_real64) return
    stopped = elapsed_time(control) >= control%deadline
  end function cancelled

  logical function clock_limit_reached(control, result) result(stopped)
    class(uci_control), intent(inout) :: control
    type(search_result), intent(in) :: result
    real(real64) :: elapsed
    integer(int64) :: iteration_nodes
    logical :: stable

    stopped = control%search_control%stop_after_depth(result)
    if (stopped .or. control%budget%soft < 0.0_real64) return
    elapsed = elapsed_time(control)
    iteration_nodes = control%nodes - control%previous_nodes
    stable = result%depth >= 3 .and. result%move == control%previous_move
    control%deadline = merge(control%budget%soft, control%budget%hard, stable)
    stopped = stop_after_iteration(control%budget%soft, elapsed, elapsed - control%previous_elapsed, &
      iteration_nodes, control%previous_iteration_nodes, stable)
    control%previous_elapsed = elapsed
    control%previous_nodes = control%nodes
    control%previous_iteration_nodes = iteration_nodes
    control%previous_move = result%move
  end function clock_limit_reached

  real(real64) function elapsed_time(control) result(seconds)
    class(uci_control), intent(in) :: control
    integer(int64) :: now

    call system_clock(count=now)
    seconds = real(now - control%start_tick, real64) / real(control%tick_rate, real64)
  end function elapsed_time

  logical function set_position(line, cursor, pos, history) result(ok)
    character(len=*), intent(in) :: line
    integer, intent(inout) :: cursor
    type(position), intent(inout) :: pos
    type(position_history), intent(inout) :: history
    type(position) :: candidate
    type(position_history) :: replay
    type(move_list) :: legal
    type(undo_state) :: undo
    character(len=:), allocatable :: mode, fen, word
    integer :: field
    integer(int32) :: move

    ok = .false.
    mode = next_word(line, cursor)
    select case (mode)
    case ('startpos')
      fen = start_fen
    case ('fen')
      fen = next_word(line, cursor)
      do field = 2, 6
        word = next_word(line, cursor)
        if (len(word) == 0) return
        fen = fen // ' ' // word
      end do
    case default
      return
    end select
    if (.not. parse_fen(fen, candidate)) return
    call reset_history(candidate, replay)
    word = next_word(line, cursor)
    if (len(word) /= 0 .and. word /= 'moves') return
    do
      word = next_word(line, cursor)
      if (len(word) == 0) exit
      if (.not. parse_move(word, move)) return
      call generate_legal(candidate, legal)
      if (.not. any(legal%moves(:legal%count) == move)) return
      call make_move(candidate, move, undo)
      call record_game_position(candidate, replay)
    end do
    pos = candidate
    history = replay
    ok = .true.
  end function set_position

  logical function parse_go(line, cursor, settings) result(ok)
    character(len=*), intent(in) :: line
    integer, intent(inout) :: cursor
    type(search_settings), intent(out) :: settings
    character(len=:), allocatable :: token, argument
    integer :: status
    integer(int32) :: move
    integer(int64) :: value
    logical :: reading_moves

    settings = search_settings()
    reading_moves = .false.
    ok = .false.
    do
      token = next_word(line, cursor)
      if (len(token) == 0) exit
      select case (token)
      case ('infinite')
        settings%infinite = .true.
        reading_moves = .false.
      case ('searchmoves')
        settings%restrict_moves = .true.
        reading_moves = .true.
      case ('wtime', 'btime', 'winc', 'binc', 'movetime', 'movestogo', 'depth', 'nodes', 'mate')
        reading_moves = .false.
        argument = next_word(line, cursor)
        if (len(argument) == 0 .or. verify(argument, '0123456789') /= 0) return
        read (argument, *, iostat=status) value
        if (status /= 0) return
        select case (token)
        case ('wtime')
          settings%remaining(1) = value
        case ('btime')
          settings%remaining(2) = value
        case ('winc')
          settings%increment(1) = value
        case ('binc')
          settings%increment(2) = value
        case ('movetime')
          settings%movetime = value
        case ('movestogo')
          if (value == 0) return
          settings%moves_to_go = value
        case ('depth', 'mate')
          if (value == 0) return
          value = min(value, int(max_search_depth, int64))
          if (token == 'mate') value = 2 * value - 1
          settings%depth = int(min(value, int(max_search_depth, int64)))
        case ('nodes')
          if (value == 0) return
          settings%nodes = value
        end select
      case default
        if (.not. reading_moves) cycle
        if (.not. parse_move(token, move)) return
        if (settings%allowed%count == max_moves) return
        settings%allowed%count = settings%allowed%count + 1
        settings%allowed%moves(settings%allowed%count) = move
      end select
    end do
    if (settings%restrict_moves .and. settings%allowed%count == 0) return
    ok = .true.
  end function parse_go

  subroutine filter_roots(roots, allowed)
    type(move_list), intent(inout) :: roots
    type(move_list), intent(in) :: allowed
    integer :: i, kept

    kept = 0
    do i = 1, roots%count
      if (.not. any(allowed%moves(:allowed%count) == roots%moves(i))) cycle
      kept = kept + 1
      roots%moves(kept) = roots%moves(i)
    end do
    roots%count = kept
  end subroutine filter_roots

  function next_word(line, cursor) result(word)
    character(len=*), intent(in) :: line
    integer, intent(inout) :: cursor
    character(len=:), allocatable :: word
    character(len=*), parameter :: spaces = ' ' // achar(9) // achar(13)
    integer :: first, length

    first = verify(line(cursor:), spaces)
    word = ''
    if (first == 0) return
    first = cursor + first - 1
    length = scan(line(first:), spaces)
    cursor = len(line) + 1
    if (length /= 0) cursor = first + length - 1
    word = line(first:cursor-1)
  end function next_word

  subroutine identify()
    call send_line('id name ' // engine_name)
    call send_line('id author philyawj')
    call send_line('uciok')
  end subroutine identify

  subroutine report_depth(result, nodes)
    type(search_result), intent(in) :: result
    integer(int64), intent(in) :: nodes
    character(len=100) :: line
    integer :: score

    score = result%score
    if (abs(score) >= mate_threshold) then
      write (line, '(a,i0,a,i0,a,i0,2a)') 'info depth ', result%depth, ' nodes ', nodes, ' score mate ', &
        sign((mate_score - abs(score) + 1) / 2, score), ' pv ', trim(move_text(result%move))
    else
      write (line, '(a,i0,a,i0,a,i0,2a)') 'info depth ', result%depth, ' nodes ', nodes, ' score cp ', score, &
        ' pv ', trim(move_text(result%move))
    end if
    call send_line(trim(line))
  end subroutine report_depth

  subroutine send_line(line)
    character(len=*), intent(in) :: line
    write (output_unit, '(a)') line
    flush (output_unit)
  end subroutine send_line

end module uci_session
