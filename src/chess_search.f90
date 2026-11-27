module chess_search
  use, intrinsic :: iso_fortran_env, only: int32, int64
  use chess_moves, only: white, pawn, knight, bishop, rook, queen, king
  use chess_movegen, only: generate_legal, in_check, move_list
  use chess_positions, only: position, undo_state, make_move, unmake_move
  implicit none
  private

  integer, parameter, public :: max_search_depth = 64, mate_score = 30000
  integer, parameter :: infinity = 32000
  integer, parameter :: piece_value(6) = [100, 320, 330, 500, 900, 0]

  type, abstract, public :: search_control
    integer(int64) :: nodes = 0, node_limit = huge(0_int64)
    logical :: interrupted = .false.
  contains
    procedure(check_interrupt), deferred :: cancelled
  end type search_control

  abstract interface
    logical function check_interrupt(control) result(stopped)
      import :: search_control
      class(search_control), intent(inout) :: control
    end function check_interrupt
  end interface

  public :: search_depth

contains

  subroutine search_depth(pos, roots, depth, control, best_move, best_score)
    type(position), intent(inout) :: pos
    type(move_list), intent(in) :: roots
    integer, intent(in) :: depth
    class(search_control), intent(inout) :: control
    integer(int32), intent(out) :: best_move
    integer, intent(out) :: best_score
    type(undo_state) :: undo
    integer :: i, score

    best_score = -infinity
    best_move = roots%moves(1)
    do i = 1, roots%count
      if (control%cancelled()) then
        control%interrupted = .true.
        return
      end if
      call make_move(pos, roots%moves(i), undo)
      score = -negamax(pos, depth - 1, 1, -infinity, -best_score, control)
      call unmake_move(pos, roots%moves(i), undo)
      if (control%interrupted) return
      if (score > best_score) then
        best_score = score
        best_move = roots%moves(i)
      end if
    end do
  end subroutine search_depth

  recursive integer function negamax(pos, depth, ply, alpha, beta, control) result(score)
    type(position), intent(inout) :: pos
    integer, intent(in) :: depth, ply, alpha, beta
    class(search_control), intent(inout) :: control
    type(undo_state) :: undo
    type(move_list) :: legal
    integer :: i, child, bound

    score = 0
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
    call generate_legal(pos, legal)
    if (legal%count == 0) then
      if (in_check(pos, pos%turn)) score = ply - mate_score
      return
    end if
    if (depth == 0) then
      score = evaluate(pos)
      return
    end if

    bound = alpha
    score = -infinity
    do i = 1, legal%count
      call make_move(pos, legal%moves(i), undo)
      child = -negamax(pos, depth - 1, ply + 1, -beta, -bound, control)
      call unmake_move(pos, legal%moves(i), undo)
      if (control%interrupted) return
      score = max(score, child)
      if (score >= beta) return
      bound = max(bound, score)
    end do
  end function negamax

  pure integer function evaluate(pos) result(score)
    type(position), intent(in) :: pos
    integer :: square, piece, kind, rank, file, center, placement

    score = 0
    do square = 0, 63
      piece = pos%board(square)
      if (piece == 0) cycle
      kind = abs(piece)
      rank = square / 8
      if (piece < 0) rank = 7 - rank
      file = mod(square, 8)
      center = min(file, 7 - file) + min(rank, 7 - rank)
      select case (kind)
      case (pawn)
        placement = 5 * rank + 3 * min(file, 7 - file)
      case (knight)
        placement = 8 * center
      case (bishop)
        placement = 5 * center
      case (rook)
        placement = 3 * rank
      case (queen)
        placement = 2 * center
      case (king)
        placement = -3 * center
      case default
        placement = 0
      end select
      score = score + sign(1, piece) * (piece_value(kind) + placement)
    end do
    if (pos%turn /= white) score = -score
  end function evaluate

end module chess_search
