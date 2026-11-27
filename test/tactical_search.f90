program tactical_search
  use, intrinsic :: iso_fortran_env, only: error_unit, int32, int64
  use chess_moves, only: parse_move, move_text
  use chess_positions, only: position, undo_state, parse_fen, to_fen, make_move, start_fen
  use chess_movegen, only: generate_legal, move_list
  use chess_draws
  use chess_search
  implicit none

  type(position) :: pos, prior
  type(position_history) :: history
  type(search_control) :: control
  type(search_result) :: answer
  type(move_list) :: legal
  integer :: i

  call load(start_fen)
  do i = 2, 5
    call advance('g1f3')
    call advance('g8f6')
    call advance('f3g1')
    call advance('f6g8')
    call check(repetitions(history) == i, 'exact repetition count')
    call check(claimable_draw(pos, history) .eqv. (i >= 3), 'threefold claim threshold')
    call check(automatic_draw(pos, history) .eqv. (i >= 5), 'fivefold termination threshold')
  end do
  call search()
  call check(answer%score == 0 .and. control%nodes == 0 .and. answer%move /= 0, 'fivefold root draw')

  call load('4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2')
  call king_cycle('e8f8', 'f8e8')
  call check(repetitions(history) == 1, 'legal en passant differentiates the earlier position')
  call load('k3r3/8/8/3pP3/8/8/8/4K3 w - d6 0 2')
  call king_cycle('a8b8', 'b8a8')
  call check(repetitions(history) == 2, 'pinned en passant is irrelevant for repetition')
  call load('4k3/8/8/3p4/8/8/8/4K3 w - d6 0 2')
  call king_cycle('e8f8', 'f8e8')
  call check(repetitions(history) == 2, 'en passant with no adjacent pawn is irrelevant')
  call load('4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1')
  do i = 1, 2
    call advance('h1h2')
    call advance('e8f8')
    call advance('h2h1')
    call advance('f8e8')
    call check(repetitions(history) == i, 'castling right differentiates the earlier position')
  end do

  call load('4k2r/p7/8/8/8/8/8/4K3 w - - 99 60')
  call check(.not. claimable_draw(pos, history), '99 halfmoves have no current claim')
  call search('e1d1')
  call check(answer%score == 0 .and. answer%depth == 1, '50-move claim by intended root move')
  call load('4k2r/p7/8/8/8/8/8/4K3 b - - 98 60')
  call search('h8h7')
  call check(answer%score == 0 .and. control%nodes == 1, 'quiet intended claim at the quiescence frontier')
  call load('4k2r/p7/8/8/8/8/8/4K3 b - - 100 60')
  call check(claimable_draw(pos, history) .and. .not. automatic_draw(pos, history), 'claim at 100 is optional')
  call search('a7a6')
  call check(answer%score > 500, 'winning pawn move available despite a current claim')
  call load('4k2r/p7/8/8/8/8/8/4K3 b - - 149 76')
  call check(claimable_draw(pos, history) .and. .not. automatic_draw(pos, history), '149 halfmoves still optional')
  call search('h8h7')
  call check(answer%score == 0, 'automatic draw after the 150th halfmove')
  call load('4k2r/p7/8/8/8/8/8/4K3 b - - 150 76')
  call search()
  call check(answer%score == 0 .and. control%nodes == 0, 'automatic draw at 150 halfmoves')

  call load('r3k3/8/8/8/8/8/8/4K3 b - - 0 1')
  call advance('e8f8')
  call advance('e1f1')
  call advance('f8e8')
  call advance('f1e1')
  call advance('e8f8')
  call advance('e1f1')
  prior = pos
  call search('f8e8')
  call check(answer%score == 0, 'opponent can intend a third position at the quiet frontier')
  call load(to_fen(prior))
  call search('f8e8')
  call check(answer%score > 400, 'same FEN without its history has no repetition claim')

  call check_dead('4k3/8/8/8/8/8/8/4K3 w - - 0 1', .true.)
  call check_dead('4k3/8/8/8/8/8/8/1N2K3 w - - 0 1', .true.)
  call check_dead('4k3/8/8/8/8/8/8/2B1K3 w - - 0 1', .true.)
  call check_dead('4k3/8/8/4b3/8/8/8/2B1K3 w - - 0 1', .true.)
  call check_dead('4k3/8/8/3b4/8/8/8/2B1K3 w - - 0 1', .false.)
  call check_dead('4k3/8/8/8/8/8/8/1NN1K3 w - - 0 1', .false.)

  call load('7k/5Q2/6K1/8/8/8/8/8 w - - 149 76')
  call search('f7g7')
  call check(answer%score == mate_score - 1, 'a mating 150th halfmove takes precedence')
  call load('7k/6Q1/5K2/8/8/8/8/8 b - - 150 76')
  call search()
  call check(answer%score == -mate_score .and. answer%move == 0, 'checkmate terminal takes precedence')
  call load('7k/5K2/6Q1/8/8/8/8/8 b - - 150 76')
  call search()
  call check(answer%score == 0 .and. answer%move == 0, 'stalemate terminal scores zero')
  call load('7k/5K2/8/6Q1/8/8/8/8 w - - 0 1')
  call search('g5g6')
  call check(answer%score == 0 .and. control%nodes == 1, 'stalemate at the quiet frontier must precede stand pat')
  call load('8/8/8/5Q2/8/5K2/8/6k1 w - - 0 1')
  call search(depth=3)
  call check(answer%score == mate_score - 3, 'forced mate in two has a three-ply distance')

  call load('4kr2/8/5p2/8/8/8/5Q2/4K3 w - - 0 1')
  call search('f2f6', 1_int64)
  call check(answer%depth == 0 .and. control%nodes == 1 .and. control%interrupted, 'node cap cuts quiescence')
  call check(move_text(answer%move) == 'f2f6', 'fallback remains legal with an incomplete search')
  call search('f2f6')
  call check(answer%depth == 1 .and. answer%score < -450 .and. control%nodes >= 2, 'quiescence sees the recapture')
  call search()
  call check(move_text(answer%move) /= 'f2f6', 'avoid the poisoned capture')
  call load('7k/8/6p1/8/8/8/8/KR6 w - - 0 1')
  call search('b1b8')
  call check(answer%depth == 1 .and. control%nodes >= 2, 'quiescence searches quiet check evasions')
  call load('4k3/8/8/8/8/8/p7/4K3 w - - 0 1')
  call search('e1f1')
  call check(answer%score < -750 .and. control%nodes >= 5, 'quiescence searches quiet promotions')
  call load('4k3/8/8/8/3p4/8/4P3/4K3 w - - 0 1')
  call search('e2e4')
  call check(answer%score < -90 .and. control%nodes >= 2, 'quiescence searches en passant')

contains

  subroutine load(fen)
    character(len=*), intent(in) :: fen

    call check(parse_fen(fen, pos), 'bad test FEN: ' // fen)
    call reset_history(pos, history)
  end subroutine load

  subroutine advance(text)
    character(len=*), intent(in) :: text
    type(undo_state) :: discard
    integer(int32) :: move

    call check(parse_move(text, move), 'bad test move: ' // text)
    call generate_legal(pos, legal)
    call check(any(legal%moves(:legal%count) == move), 'illegal test move: ' // text)
    call make_move(pos, move, discard)
    call record_game_position(pos, history)
  end subroutine advance

  subroutine king_cycle(away, back)
    character(len=*), intent(in) :: away, back

    call advance('e1f1')
    call advance(away)
    call advance('f1e1')
    call advance(back)
  end subroutine king_cycle

  subroutine search(text, nodes, depth)
    character(len=*), optional, intent(in) :: text
    integer(int64), optional, intent(in) :: nodes
    integer, optional, intent(in) :: depth
    integer(int32) :: move
    integer :: occurrences, limit
    integer(int64) :: expected_nodes
    logical :: expected_interrupt
    type(search_result) :: expected
    character(len=:), allocatable :: before

    before = to_fen(pos)
    occurrences = repetitions(history)
    call generate_legal(pos, legal)
    if (present(text)) then
      call check(parse_move(text, move), 'bad root restriction: ' // text)
      call check(any(legal%moves(:legal%count) == move), 'illegal root restriction: ' // text)
      legal%count = 1
      legal%moves(1) = move
    end if
    control%node_limit = huge(0_int64)
    if (present(nodes)) control%node_limit = nodes
    limit = 1
    if (present(depth)) limit = depth
    control%mode = history_mode
    call control%table%clear()
    call iterative_search(pos, history, legal, limit, control, expected)
    expected_nodes = control%nodes
    expected_interrupt = control%interrupted
    call check(to_fen(pos) == before .and. repetitions(history) == occurrences, 'control restores the root')
    control%mode = staged_mode
    call control%table%clear()
    call iterative_search(pos, history, legal, limit, control, answer)
    call check(answer%depth == expected%depth .and. answer%score == expected%score .and. answer%move == expected%move, &
      'staged search must match the control decision')
    call check(control%nodes == expected_nodes .and. (control%interrupted .eqv. expected_interrupt), &
      'staged search must match the control node work')
    call check(to_fen(pos) == before, 'search restores the board and clocks')
    call check(repetitions(history) == occurrences, 'search restores the root history')
  end subroutine search

  subroutine check_dead(fen, expected)
    character(len=*), intent(in) :: fen
    logical, intent(in) :: expected

    call load(fen)
    call check(dead_material(pos) .eqv. expected, 'wrong dead material status: ' // fen)
  end subroutine check_dead

  subroutine check(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (condition) return
    write (error_unit, '(a)') message
    stop 1
  end subroutine check

end program tactical_search
