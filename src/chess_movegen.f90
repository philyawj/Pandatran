module chess_movegen
  use, intrinsic :: iso_fortran_env, only: int32, int64
  use chess_moves
  use chess_positions, only: position, undo_state, make_move, unmake_move
  implicit none
  private

  type, public :: move_list
    integer(int32) :: moves(max_moves)
    integer :: count = 0
  end type move_list

  integer :: square
  integer(int64), parameter :: bits(0:63) = [(shiftl(1_int64, square), square=0,63)]
  integer(int64), parameter :: file_a = int(z'0101010101010101', int64)
  integer(int64), parameter :: file_b = shiftl(file_a, 1)
  integer(int64), parameter :: file_h = shiftl(file_a, 7)
  integer(int64), parameter :: file_g = shiftl(file_a, 6)
  integer(int64), parameter :: east(0:63) = shiftl(iand(bits, not(file_h)), 1)
  integer(int64), parameter :: west(0:63) = shiftr(iand(bits, not(file_a)), 1)
  integer(int64), parameter :: adjacent(0:63) = ior(east, west)
  integer(int64), parameter :: king_attacks(0:63) = &
    ior(adjacent, ior(shiftl(ior(bits, adjacent), 8), shiftr(ior(bits, adjacent), 8)))
  integer(int64), parameter :: two_east(0:63) = shiftl(iand(bits, not(ior(file_g, file_h))), 2)
  integer(int64), parameter :: two_west(0:63) = shiftr(iand(bits, not(ior(file_a, file_b))), 2)
  integer(int64), parameter :: two_adjacent(0:63) = ior(two_east, two_west)
  integer(int64), parameter :: knight_attacks(0:63) = ior( &
    ior(shiftl(adjacent, 16), shiftr(adjacent, 16)), &
    ior(shiftl(two_adjacent, 8), shiftr(two_adjacent, 8)))
  integer(int64), parameter :: pawn_attacks(0:63, 2) = &
    reshape([shiftl(adjacent, 8), shiftr(adjacent, 8)], [64, 2])
  integer, parameter :: file_delta(8) = [1, -1, 0, 0, 1, -1, 1, -1]
  integer, parameter :: rank_delta(8) = [0, 0, 1, -1, 1, 1, -1, -1]

  public :: generate_legal, in_check, piece_targets, pawn_pressure

contains

  logical function in_check(pos, side) result(checked)
    type(position), intent(in) :: pos
    integer, intent(in) :: side

    checked = is_attacked(pos, trailz(pos%pieces(king, side)), other_side(side))
  end function in_check

  logical function is_attacked(pos, target, by_side) result(attacked)
    type(position), intent(in) :: pos
    integer, intent(in) :: target, by_side
    integer(int64) :: occupied, orthogonal, diagonal
    integer :: direction
    logical :: check_ray(8)

    attacked = .true.
    if (iand(pawn_attacks(target, other_side(by_side)), pos%pieces(pawn, by_side)) /= 0) return
    if (iand(knight_attacks(target), pos%pieces(knight, by_side)) /= 0) return
    if (iand(king_attacks(target), pos%pieces(king, by_side)) /= 0) return

    orthogonal = ior(pos%pieces(rook, by_side), pos%pieces(queen, by_side))
    diagonal = ior(pos%pieces(bishop, by_side), pos%pieces(queen, by_side))
    occupied = ior(pos%occupied(white), pos%occupied(black))
    check_ray(1:4) = orthogonal /= 0
    check_ray(5:8) = diagonal /= 0
    do direction = 1, 8
      if (.not. check_ray(direction)) cycle
      if (iand(ray(target, direction, occupied), merge(orthogonal, diagonal, direction <= 4)) /= 0) return
    end do
    attacked = .false.
  end function is_attacked

  pure integer(int64) function ray(origin, direction, occupied) result(targets)
    integer, intent(in) :: origin, direction
    integer(int64), intent(in) :: occupied
    integer :: file, rank, target

    targets = 0_int64
    file = mod(origin, 8)
    rank = origin / 8
    do
      file = file + file_delta(direction)
      rank = rank + rank_delta(direction)
      if (file < 0 .or. file > 7 .or. rank < 0 .or. rank > 7) exit
      target = rank * 8 + file
      targets = ibset(targets, target)
      if (btest(occupied, target)) exit
    end do
  end function ray

  pure integer(int64) function piece_targets(origin, kind, occupied) result(targets)
    integer, intent(in) :: origin, kind
    integer(int64), intent(in) :: occupied
    integer, parameter :: first_direction(bishop:queen) = [5, 1, 1]
    integer, parameter :: last_direction(bishop:queen) = [8, 4, 8]
    integer :: direction

    targets = 0_int64
    select case (kind)
    case (knight)
      targets = knight_attacks(origin)
    case (king)
      targets = king_attacks(origin)
    case (bishop:queen)
      do direction = first_direction(kind), last_direction(kind)
        targets = ior(targets, ray(origin, direction, occupied))
      end do
    end select
  end function piece_targets

  pure integer(int64) function pawn_pressure(pawns, side) result(targets)
    integer(int64), intent(in) :: pawns
    integer, intent(in) :: side
    integer(int64) :: sideways

    sideways = ior(shiftl(iand(pawns, not(file_h)), 1), shiftr(iand(pawns, not(file_a)), 1))
    if (side == white) then
      targets = shiftl(sideways, 8)
    else
      targets = shiftr(sideways, 8)
    end if
  end function pawn_pressure

  subroutine generate_legal(pos, list)
    type(position), intent(inout) :: pos
    type(move_list), intent(out) :: list
    type(undo_state) :: undo
    integer :: i, mover, candidates
    integer(int32) :: move
    logical :: legal

    call generate_candidates(pos, list)
    mover = pos%turn
    candidates = list%count
    list%count = 0
    do i = 1, candidates
      move = list%moves(i)
      call make_move(pos, move, undo)
      legal = .not. in_check(pos, mover)
      call unmake_move(pos, move, undo)
      if (legal) call append_move(list, move)
    end do
  end subroutine generate_legal

  subroutine generate_candidates(pos, list)
    type(position), intent(in) :: pos
    type(move_list), intent(out) :: list
    integer :: side, opponent, origin, kind
    integer(int64) :: pieces, occupied, available, captures, targets

    list%count = 0
    side = pos%turn
    opponent = other_side(side)
    occupied = ior(pos%occupied(side), pos%occupied(opponent))
    captures = iand(pos%occupied(opponent), not(pos%pieces(king, opponent)))
    available = not(ior(pos%occupied(side), pos%pieces(king, opponent)))
    if (pos%ep /= no_square) captures = ibset(captures, pos%ep)
    pieces = pos%occupied(side)
    do while (pieces /= 0)
      origin = next_square(pieces)
      kind = abs(pos%board(origin))
      if (kind == pawn) then
        call generate_pawn(pos, origin, captures, occupied, list)
        cycle
      end if
      targets = iand(piece_targets(origin, kind, occupied), available)
      do while (targets /= 0)
        call append_move(list, pack_move(origin, next_square(targets)))
      end do
    end do
    call generate_castles(pos, occupied, list)
  end subroutine generate_candidates

  subroutine generate_pawn(pos, origin, captures, occupied, list)
    type(position), intent(in) :: pos
    integer, intent(in) :: origin
    integer(int64), intent(in) :: captures, occupied
    type(move_list), intent(inout) :: list
    integer :: target, step, home_rank
    integer(int64) :: targets

    step = pawn_step(pos%turn)
    home_rank = merge(1, 6, pos%turn == white)
    target = origin + step
    if (.not. btest(occupied, target)) then
      call append_pawn_move(list, origin, target)
      if (origin / 8 == home_rank) then
        if (.not. btest(occupied, target + step)) call append_move(list, pack_move(origin, target + step))
      end if
    end if
    targets = iand(pawn_attacks(origin, pos%turn), captures)
    do while (targets /= 0)
      call append_pawn_move(list, origin, next_square(targets))
    end do
  end subroutine generate_pawn

  subroutine generate_castles(pos, occupied, list)
    type(position), intent(in) :: pos
    integer(int64), intent(in) :: occupied
    type(move_list), intent(inout) :: list
    integer :: origin, opponent, side, transit

    side = pos%turn
    if (iand(pos%castling, ior(king_side(side), queen_side(side))) == 0) return
    origin = home_king(side)
    opponent = other_side(side)
    if (is_attacked(pos, origin, opponent)) return
    if (iand(pos%castling, king_side(side)) /= 0) then
      transit = origin + 1
      if (.not. btest(occupied, transit) .and. .not. btest(occupied, origin + 2)) then
        if (.not. is_attacked(pos, transit, opponent)) call append_move(list, pack_move(origin, origin + 2))
      end if
    end if
    if (iand(pos%castling, queen_side(side)) /= 0) then
      transit = origin - 1
      if (ibits(occupied, origin - 3, 3) == 0) then
        if (.not. is_attacked(pos, transit, opponent)) call append_move(list, pack_move(origin, origin - 2))
      end if
    end if
  end subroutine generate_castles

  subroutine append_pawn_move(list, origin, target)
    type(move_list), intent(inout) :: list
    integer, intent(in) :: origin, target
    integer :: promotion

    if (target / 8 == 0 .or. target / 8 == 7) then
      do promotion = knight, queen
        call append_move(list, pack_move(origin, target, promotion))
      end do
    else
      call append_move(list, pack_move(origin, target))
    end if
  end subroutine append_pawn_move

  subroutine append_move(list, move)
    type(move_list), intent(inout) :: list
    integer(int32), intent(in) :: move

    ! A side has at most 16 pieces, with at most 27 candidates per piece.
    list%count = list%count + 1
    list%moves(list%count) = move
  end subroutine append_move

  integer function next_square(mask) result(origin)
    integer(int64), intent(inout) :: mask
    origin = trailz(mask)
    mask = ibclr(mask, origin)
  end function next_square

end module chess_movegen
