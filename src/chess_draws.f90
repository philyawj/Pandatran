module chess_draws
  use, intrinsic :: iso_fortran_env, only: int64
  use chess_moves, only: pawn, knight, bishop, rook, queen, no_square, pawn_step, colored_piece, pack_move
  use chess_positions, only: position, undo_state, make_move, unmake_move
  use chess_movegen, only: in_check
  use chess_hashes, only: extend_history_key
  implicit none
  private

  integer, parameter, public :: claim_halfmoves = 100
  integer, parameter :: automatic_halfmoves = 150, game_positions = automatic_halfmoves + 1
  integer, parameter :: search_path = 128

  type :: repetition_entry
    integer(int64) :: occupied(2) = 0, pieces(6, 2) = 0, context = 0
    integer :: turn = 0, castling = 0, ep = no_square, occurrences = 0
  end type repetition_entry

  type, public :: position_history
    private
    type(repetition_entry) :: entries(game_positions + search_path)
    integer :: count = 0
  end type position_history

  public :: reset_history, record_game_position, push_position, pop_position, repetitions
  public :: claimable_draw, automatic_draw, possible_intended_claim, dead_material, history_key

contains

  subroutine reset_history(pos, history)
    type(position), intent(inout) :: pos
    type(position_history), intent(out) :: history

    call push_position(pos, history)
  end subroutine reset_history

  subroutine record_game_position(pos, history)
    type(position), intent(inout) :: pos
    type(position_history), intent(inout) :: history

    if (pos%halfmove == 0) history%count = 0
    if (history%count == game_positions) then
      history%entries(1:game_positions-1) = history%entries(2:game_positions)
      history%count = game_positions - 1
    end if
    call push_position(pos, history)
  end subroutine record_game_position

  subroutine push_position(pos, history)
    type(position), intent(inout) :: pos
    type(position_history), intent(inout) :: history
    type(repetition_entry) :: entry
    integer :: i, oldest

    entry%occupied = pos%occupied
    entry%pieces = pos%pieces
    entry%turn = pos%turn
    entry%castling = pos%castling
    entry%ep = repetition_ep(pos)
    entry%occurrences = 1
    entry%context = pos%key
    if (history%count > 0 .and. pos%halfmove > 0) then
      associate (previous => history%entries(history%count))
        if (previous%castling == pos%castling) entry%context = extend_history_key(previous%context, pos%key)
      end associate
    end if
    oldest = first_reversible(pos, history%count + 1)

    ! A legal position cannot recur in fewer than four plies.
    do i = history%count - 3, oldest, -2
      associate (prior => history%entries(i))
        if (prior%castling /= entry%castling) exit
        if (prior%turn /= entry%turn .or. prior%ep /= entry%ep) cycle
        if (any(prior%occupied /= entry%occupied)) cycle
        if (any(prior%pieces /= entry%pieces)) cycle
        entry%occurrences = prior%occurrences + 1
        exit
      end associate
    end do
    history%count = history%count + 1
    history%entries(history%count) = entry
  end subroutine push_position

  subroutine pop_position(history)
    type(position_history), intent(inout) :: history
    history%count = history%count - 1
  end subroutine pop_position

  pure integer(int64) function history_key(history) result(key)
    type(position_history), intent(in) :: history
    key = history%entries(history%count)%context
  end function history_key

  pure integer function repetitions(history) result(count)
    type(position_history), intent(in) :: history
    count = history%entries(history%count)%occurrences
  end function repetitions

  pure logical function claimable_draw(pos, history) result(draw)
    type(position), intent(in) :: pos
    type(position_history), intent(in) :: history
    draw = pos%halfmove >= claim_halfmoves .or. repetitions(history) >= 3
  end function claimable_draw

  pure logical function automatic_draw(pos, history) result(draw)
    type(position), intent(in) :: pos
    type(position_history), intent(in) :: history
    draw = pos%halfmove >= automatic_halfmoves .or. repetitions(history) >= 5 .or. dead_material(pos)
  end function automatic_draw

  pure logical function possible_intended_claim(pos, history) result(possible)
    type(position), intent(in) :: pos
    type(position_history), intent(in) :: history
    integer :: i

    possible = .true.
    if (pos%halfmove >= claim_halfmoves - 1) return
    do i = history%count - 3, first_reversible(pos, history%count), -2
      if (history%entries(i)%castling /= pos%castling) exit
      if (history%entries(i)%occurrences >= 2) return
    end do
    possible = .false.
  end function possible_intended_claim

  pure integer function first_reversible(pos, count) result(index)
    type(position), intent(in) :: pos
    integer, intent(in) :: count

    index = count - int(min(pos%halfmove, int(count - 1, int64)))
  end function first_reversible

  integer function repetition_ep(pos) result(target)
    type(position), intent(inout) :: pos
    type(undo_state) :: undo
    integer :: square, side, origin, offset
    logical :: legal

    target = no_square
    square = pos%ep
    if (square == no_square) return
    side = pos%turn
    do offset = -1, 1, 2
      if (mod(square, 8) + offset < 0 .or. mod(square, 8) + offset > 7) cycle
      origin = square - pawn_step(side) + offset
      if (pos%board(origin) /= colored_piece(pawn, side)) cycle
      call make_move(pos, pack_move(origin, square), undo)
      legal = .not. in_check(pos, side)
      call unmake_move(pos, pack_move(origin, square), undo)
      if (.not. legal) cycle
      target = square
      return
    end do
  end function repetition_ep

  pure logical function dead_material(pos) result(draw)
    type(position), intent(in) :: pos
    integer(int64), parameter :: dark = int(z'AA55AA55AA55AA55', int64)
    integer(int64) :: bishops

    draw = .false.
    if (any(pos%pieces(pawn, :) /= 0) .or. any(pos%pieces(rook:queen, :) /= 0)) return
    if (sum(popcnt(pos%pieces(knight:bishop, :))) <= 1) then
      draw = .true.
    else if (all(pos%pieces(knight, :) == 0)) then
      bishops = ior(pos%pieces(bishop, 1), pos%pieces(bishop, 2))
      draw = iand(bishops, dark) == 0 .or. iand(bishops, not(dark)) == 0
    end if
  end function dead_material

end module chess_draws
