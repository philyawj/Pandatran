module chess_perft
  use, intrinsic :: iso_fortran_env, only: int64
  use chess_moves, only: max_moves
  use chess_movegen, only: move_list, generate_legal
  use chess_positions, only: position, undo_state, make_move, unmake_move
  implicit none
  private
  public :: perft, perft_divide

contains

  ! Depth zero is the current position. Perft counts paths regardless of draw claims.
  recursive integer(int64) function perft(pos, depth) result(nodes)
    type(position), intent(inout) :: pos
    integer, intent(in) :: depth
    type(move_list) :: list
    type(undo_state) :: undo
    integer :: i

    if (depth == 0) then
      nodes = 1_int64
      return
    end if
    call generate_legal(pos, list)
    if (depth == 1) then
      nodes = int(list%count, int64)
      return
    end if
    nodes = 0_int64
    do i = 1, list%count
      call make_move(pos, list%moves(i), undo)
      nodes = nodes + perft(pos, depth - 1)
      call unmake_move(pos, list%moves(i), undo)
    end do
  end function perft

  subroutine perft_divide(pos, depth, list, counts)
    type(position), intent(inout) :: pos
    integer, intent(in) :: depth
    type(move_list), intent(out) :: list
    integer(int64), intent(out) :: counts(max_moves)
    type(undo_state) :: undo
    integer :: i

    call generate_legal(pos, list)
    do i = 1, list%count
      call make_move(pos, list%moves(i), undo)
      counts(i) = perft(pos, depth - 1)
      call unmake_move(pos, list%moves(i), undo)
    end do
  end subroutine perft_divide

end module chess_perft
