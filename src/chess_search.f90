module chess_search
  use, intrinsic :: iso_fortran_env, only: int16, int32, int64
  use chess_moves, only: white, pawn, knight, bishop, rook, queen, king, move_from, move_to, move_promotion
  use chess_movegen, only: generate_legal, has_legal_move, in_check, move_list
  use chess_positions, only: position, undo_state, make_move, unmake_move
  use chess_draws, only: position_history, push_position, pop_position, claimable_draw, automatic_draw, &
    possible_intended_claim, history_key, repetitions, claim_halfmoves
  use chess_evaluation, only: evaluate, default_eval, ordering_values
  use chess_transpositions, only: transposition_table, exact_bound, lower_bound, upper_bound
  implicit none
  private

  integer, parameter, public :: max_search_depth = 64, mate_score = 30000
  integer, parameter :: quiet_limit = 10, max_quiescence = 16, infinity = 32000
  integer, parameter, public :: mate_threshold = mate_score - max_search_depth - max_quiescence
  integer, parameter, public :: plain_mode = 0, order_mode = 1, table_mode = 2, pvs_mode = 3, aspiration_mode = 4
  integer, parameter, public :: lmr_mode = 5, history_mode = 6, staged_mode = 7
  integer, parameter, public :: default_mode = staged_mode
  integer, parameter :: aspiration_width = 40
  integer, parameter :: quiet_history_limit = 1024

  type, public :: search_result
    integer(int32) :: move = 0
    integer :: depth = 0, score = 0
  end type search_result

  type, public :: search_control
    integer(int64) :: nodes = 0, node_limit = huge(0_int64)
    integer(int64) :: reductions = 0, reduced_researches = 0
    logical :: interrupted = .false.
    integer :: mode = default_mode, evaluation = default_eval
    integer(int16) :: quiet_history(0:63, 0:63, 2)
    type(transposition_table) :: table
  contains
    procedure :: cancelled => uninterruptible
    procedure :: stop_after_depth => search_limit_reached
  end type search_control

  abstract interface
    subroutine report_progress(result, nodes)
      import :: search_result, int64
      type(search_result), intent(in) :: result
      integer(int64), intent(in) :: nodes
    end subroutine report_progress
  end interface

  public :: iterative_search, selective_node

contains

  logical function uninterruptible(control) result(stopped)
    class(search_control), intent(inout) :: control
    stopped = control%interrupted
  end function uninterruptible

  logical function search_limit_reached(control, result) result(stopped)
    class(search_control), intent(inout) :: control
    type(search_result), intent(in) :: result

    stopped = control%nodes >= control%node_limit .or. &
      (abs(result%score) >= mate_threshold .and. mate_score - abs(result%score) <= result%depth)
  end function search_limit_reached

  subroutine iterative_search(pos, history, roots, depth_limit, control, result, on_depth)
    type(position), intent(inout) :: pos
    type(position_history), intent(inout) :: history
    type(move_list), intent(in) :: roots
    integer, intent(in) :: depth_limit
    class(search_control), intent(inout) :: control
    type(search_result), intent(out) :: result
    procedure(report_progress), optional :: on_depth
    type(search_result) :: candidate
    type(move_list) :: ordered
    integer :: depth, alpha, beta
    integer(int32) :: hint

    control%nodes = 0
    control%reductions = 0
    control%reduced_researches = 0
    control%interrupted = .false.
    result = search_result()
    if (control%mode >= history_mode) control%quiet_history = 0
    if (roots%count == 0) then
      if (in_check(pos, pos%turn)) result%score = -mate_score
      return
    end if
    result%move = roots%moves(1)
    if (automatic_draw(pos, history)) then
      result%depth = 1
      if (present(on_depth)) call on_depth(result, control%nodes)
      return
    end if

    if (control%mode >= table_mode) call control%table%prepare()
    do depth = 1, depth_limit
      if (control%cancelled()) exit
      candidate%depth = depth
      ordered = roots
      if (control%mode >= order_mode) then
        hint = 0
        if (depth > 1) hint = result%move
        call order_main_moves(pos, ordered, hint, control)
      end if
      alpha = -infinity
      beta = infinity
      if (control%mode == aspiration_mode .and. depth > 1 .and. abs(result%score) < mate_threshold) then
        alpha = result%score - aspiration_width
        beta = result%score + aspiration_width
      end if
      call search_depth(pos, history, ordered, depth, alpha, beta, control, candidate)
      if (control%interrupted) exit
      if (candidate%score <= alpha .or. candidate%score >= beta) then
        call search_depth(pos, history, ordered, depth, -infinity, infinity, control, candidate)
        if (control%interrupted) exit
      end if
      result = candidate
      if (present(on_depth)) call on_depth(result, control%nodes)
      if (control%stop_after_depth(result)) exit
    end do
  end subroutine iterative_search

  subroutine search_depth(pos, history, roots, depth, alpha, beta, control, result)
    type(position), intent(inout) :: pos
    type(position_history), intent(inout) :: history
    type(move_list), intent(in) :: roots
    integer, intent(in) :: depth, alpha, beta
    class(search_control), intent(inout) :: control
    type(search_result), intent(inout) :: result
    integer :: i, score, bound

    result%score = -infinity
    result%move = roots%moves(1)
    bound = alpha
    do i = 1, roots%count
      if (control%cancelled()) then
        control%interrupted = .true.
        return
      end if
      score = search_branch(pos, history, roots%moves(i), depth - 1, 1, bound, beta, control, &
        i > 1 .and. control%mode >= pvs_mode, .false.)
      if (control%interrupted) return
      if (score > result%score) then
        result%score = score
        result%move = roots%moves(i)
      end if
      if (score >= beta) exit
      bound = max(bound, score)
    end do
  end subroutine search_depth

  recursive integer function search_branch(pos, history, move, depth, ply, alpha, beta, control, scout, reduce) result(score)
    type(position), intent(inout) :: pos
    type(position_history), intent(inout) :: history
    integer(int32), intent(in) :: move
    integer, intent(in) :: depth, ply, alpha, beta
    class(search_control), intent(inout) :: control
    logical, intent(in) :: scout, reduce

    if (scout .and. alpha + 1 < beta) then
      score = search_move(pos, history, move, depth, ply, alpha, alpha + 1, control, .false.)
      if (control%interrupted .or. score <= alpha .or. score >= beta) return
    end if
    score = search_move(pos, history, move, depth, ply, alpha, beta, control, reduce)
  end function search_branch

  recursive integer function search_move(pos, history, move, depth, ply, alpha, beta, control, reduce) result(score)
    type(position), intent(inout) :: pos
    type(position_history), intent(inout) :: history
    integer(int32), intent(in) :: move
    integer, intent(in) :: depth, ply, alpha, beta
    class(search_control), intent(inout) :: control
    logical, intent(in) :: reduce
    type(undo_state) :: undo
    logical :: can_claim, full_depth

    call make_move(pos, move, undo)
    call push_position(pos, history)
    full_depth = .true.
    if (reduce) then
      if (.not. in_check(pos, pos%turn)) then
        control%reductions = control%reductions + 1
        score = -negamax(pos, history, depth - 1, ply, -beta, -alpha, control, can_claim)
        if (can_claim) score = max(score, 0)
        full_depth = .not. control%interrupted .and. (score > alpha .or. abs(score) >= mate_threshold)
        if (full_depth) control%reduced_researches = control%reduced_researches + 1
      end if
    end if
    if (full_depth) score = -negamax(pos, history, depth, ply, -beta, -alpha, control, can_claim)
    call pop_position(history)
    call unmake_move(pos, move, undo)
    ! Before playing this move the mover could instead claim the draw it creates.
    if (can_claim) score = max(score, 0)
  end function search_move

  recursive integer function negamax(pos, history, depth, ply, alpha, beta, control, can_claim) result(score)
    type(position), intent(inout) :: pos
    type(position_history), intent(inout) :: history
    integer, intent(in) :: depth, ply, alpha, beta
    class(search_control), intent(inout) :: control
    logical, intent(out) :: can_claim
    type(move_list) :: legal
    logical :: quiescence, checked, stand_pat, tactical_pending, cache, hit, selective, reduce, quiet
    integer :: i, child, bound, quiet_searched
    integer(int32) :: hint, best_move
    integer(int16) :: result_bound
    integer(int64) :: context

    score = 0
    can_claim = .false.
    if (control%nodes >= control%node_limit) then
      control%interrupted = .true.
      return
    end if
    if (iand(control%nodes, 127_int64) == 0) then
      if (control%cancelled()) then
        control%interrupted = .true.
        return
      end if
    end if
    control%nodes = control%nodes + 1
    quiescence = depth <= 0
    cache = .not. quiescence .and. control%mode >= table_mode
    context = 0
    hint = 0
    if (cache) then
      context = history_key(history)
      call control%table%probe(pos%key, context, pos%halfmove, depth, ply, alpha, beta, hit, score, hint)
      if (hit) then
        can_claim = claimable_draw(pos, history)
        return
      end if
      score = 0
    end if
    checked = .false.
    if (quiescence) checked = in_check(pos, pos%turn)
    stand_pat = quiescence .and. .not. checked
    tactical_pending = stand_pat .and. control%mode == staged_mode
    if (tactical_pending) then
      if (.not. has_legal_move(pos)) return ! Stalemate
    else
      call generate_legal(pos, legal)
      if (legal%count == 0) then
        if (quiescence) then
          if (checked) score = ply - mate_score
        else if (in_check(pos, pos%turn)) then
          score = ply - mate_score
        end if
        return
      end if
    end if
    if (automatic_draw(pos, history)) return
    can_claim = claimable_draw(pos, history)
    selective = .false.
    if (control%mode >= lmr_mode) selective = selective_node(pos, history, depth, alpha, beta)

    score = -infinity
    if (stand_pat .or. depth <= -max_quiescence) score = evaluate(pos, control%evaluation)
    if (can_claim) score = max(score, 0)

    if (stand_pat .and. score < 0) then
      if (possible_intended_claim(pos, history)) then
        if (tactical_pending) call generate_legal(pos, legal)
        tactical_pending = .false.
        if (quiet_claim(pos, history, legal)) score = 0
      end if
    end if
    if (score >= beta .or. depth <= -max_quiescence) return
    if (stand_pat .and. depth <= -quiet_limit) return
    if (quiescence) then
      if (tactical_pending) call generate_legal(pos, legal, tactical_only=.true.)
      call order_moves(pos, legal, checked, 0_int32)
    else if (control%mode >= order_mode) then
      call order_main_moves(pos, legal, hint, control)
    end if
    bound = max(alpha, score)
    best_move = 0
    quiet_searched = 0
    do i = 1, legal%count
      reduce = .false.
      if (selective) then
        quiet = ordinary_quiet(pos, legal%moves(i))
        reduce = quiet .and. quiet_searched >= 3 .and. legal%moves(i) /= hint
        if (quiet) quiet_searched = quiet_searched + 1
      end if
      child = search_branch(pos, history, legal%moves(i), depth - 1, ply + 1, bound, beta, control, &
        i > 1 .and. .not. quiescence .and. control%mode >= pvs_mode, reduce)
      if (control%interrupted) return
      if (child > score) then
        score = child
        best_move = legal%moves(i)
      end if
      if (score >= beta) then
        if (control%mode >= history_mode .and. depth >= 2) &
          call learn_quiet_cutoff(pos, legal%moves(:i), depth, control%quiet_history(:, :, pos%turn))
        exit
      end if
      bound = max(bound, score)
    end do

    if (cache) then
      result_bound = exact_bound
      if (score <= alpha) result_bound = upper_bound
      if (score >= beta) result_bound = lower_bound
      call control%table%store(pos%key, context, pos%halfmove, depth, ply, score, result_bound, best_move)
    end if
  end function negamax

  logical function selective_node(pos, history, depth, alpha, beta) result(eligible)
    type(position), intent(in) :: pos
    type(position_history), intent(in) :: history
    integer, intent(in) :: depth, alpha, beta
    integer :: material(2)

    eligible = .false.
    if (depth < 3 .or. beta /= alpha + 1) return
    if (abs(alpha) >= mate_threshold .or. abs(beta) >= mate_threshold) return
    if (pos%halfmove >= claim_halfmoves - 10 .or. repetitions(history) > 1) return
    material = sum(popcnt(pos%pieces(knight:queen, :)), dim=1)
    if (any(material == 0) .or. sum(material) < 4) return
    if (possible_intended_claim(pos, history)) return
    eligible = .not. in_check(pos, pos%turn)
  end function selective_node

  pure logical function ordinary_quiet(pos, move) result(quiet)
    type(position), intent(in) :: pos
    integer(int32), intent(in) :: move
    integer :: origin, target, piece

    origin = move_from(move)
    target = move_to(move)
    piece = abs(pos%board(origin))
    quiet = piece /= pawn .and. pos%board(target) == 0 .and. move_promotion(move) == 0
    if (piece == king .and. abs(target - origin) == 2) quiet = .false.
  end function ordinary_quiet

  logical function quiet_claim(pos, history, legal) result(found)
    type(position), intent(inout) :: pos
    type(position_history), intent(inout) :: history
    type(move_list), intent(in) :: legal
    type(undo_state) :: undo
    integer(int32) :: move
    integer :: i

    do i = 1, legal%count
      move = legal%moves(i)
      if (abs(pos%board(move_from(move))) == pawn .or. pos%board(move_to(move)) /= 0) cycle
      call make_move(pos, move, undo)
      call push_position(pos, history)
      found = claimable_draw(pos, history)
      call pop_position(history)
      call unmake_move(pos, move, undo)
      if (found) return
    end do
    found = .false.
  end function quiet_claim

  subroutine order_main_moves(pos, legal, hint, control)
    type(position), intent(in) :: pos
    type(move_list), intent(inout) :: legal
    integer(int32), intent(in) :: hint
    class(search_control), intent(in) :: control

    if (control%mode >= history_mode) then
      call order_moves(pos, legal, .true., hint, control%quiet_history(:, :, pos%turn))
    else
      call order_moves(pos, legal, .true., hint)
    end if
  end subroutine order_main_moves

  subroutine learn_quiet_cutoff(pos, searched, depth, scores)
    type(position), intent(in) :: pos
    integer(int32), intent(in) :: searched(:)
    integer, intent(in) :: depth
    integer(int16), intent(inout) :: scores(0:63, 0:63)
    integer :: i, bonus

    i = size(searched)
    if (.not. history_quiet(pos, searched(i))) return
    bonus = min(256, depth**2)
    call adjust_quiet_score(scores, searched(i), bonus)
    do i = 1, size(searched) - 1
      if (history_quiet(pos, searched(i))) call adjust_quiet_score(scores, searched(i), -bonus / 2)
    end do
  end subroutine learn_quiet_cutoff

  pure logical function history_quiet(pos, move) result(quiet)
    type(position), intent(in) :: pos
    integer(int32), intent(in) :: move
    integer :: from, to

    from = move_from(move)
    to = move_to(move)
    quiet = pos%board(to) == 0 .and. move_promotion(move) == 0
    if (to == pos%ep .and. abs(pos%board(from)) == pawn) quiet = .false.
  end function history_quiet

  pure subroutine adjust_quiet_score(scores, move, bonus)
    integer(int16), intent(inout) :: scores(0:63, 0:63)
    integer(int32), intent(in) :: move
    integer, intent(in) :: bonus
    integer :: from, to, previous

    from = move_from(move)
    to = move_to(move)
    previous = scores(from, to)
    scores(from, to) = int(previous + bonus - previous * abs(bonus) / quiet_history_limit, int16)
  end subroutine adjust_quiet_score

  subroutine order_moves(pos, legal, include_quiets, hint, quiet_history)
    type(position), intent(in) :: pos
    type(move_list), intent(inout) :: legal
    logical, intent(in) :: include_quiets
    integer(int32), intent(in) :: hint
    integer(int16), optional, intent(in) :: quiet_history(0:63, 0:63)
    integer :: priorities(size(legal%moves))
    integer :: i, j, count, from, target, attacker, victim, promotion, priority
    integer(int32) :: move
    integer, parameter :: values(0:6) = [0, ordering_values]

    count = 0
    do i = 1, legal%count
      move = legal%moves(i)
      from = move_from(move)
      target = move_to(move)
      attacker = abs(pos%board(from))
      victim = abs(pos%board(target))
      if (target == pos%ep .and. attacker == pawn) victim = pawn
      promotion = move_promotion(move)
      if (victim == 0 .and. promotion == 0) then
        if (.not. include_quiets) cycle
        priority = -infinity
        if (present(quiet_history)) priority = -quiet_history_limit - 1 + quiet_history(from, target)
      else
        priority = 16 * (values(victim) + values(promotion)) - values(attacker)
      end if
      if (move == hint) priority = infinity
      j = count
      do while (j > 0)
        if (priorities(j) >= priority) exit
        priorities(j + 1) = priorities(j)
        legal%moves(j + 1) = legal%moves(j)
        j = j - 1
      end do
      priorities(j + 1) = priority
      legal%moves(j + 1) = move
      count = count + 1
    end do
    legal%count = count
  end subroutine order_moves

end module chess_search
