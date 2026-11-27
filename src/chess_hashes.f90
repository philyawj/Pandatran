module chess_hashes
  use, intrinsic :: iso_fortran_env, only: int64
  use chess_moves, only: black
  implicit none
  private

  integer(int64), protected, public :: piece_keys(0:63, -6:6)
  integer(int64) :: castle_keys(0:15), ep_keys(0:63), black_key
  logical :: initialized = .false.

  public :: initialize_keys, state_key, extend_history_key

contains

  subroutine initialize_keys()
    integer(int64) :: stream
    integer :: square, piece

    if (initialized) return
    stream = int(z'9E3779B97F4A7C15', int64)
    do piece = -6, 6
      if (piece == 0) cycle
      do square = 0, 63
        piece_keys(square, piece) = next_key(stream)
      end do
    end do
    piece_keys(:, 0) = 0
    do square = 0, 63
      ep_keys(square) = next_key(stream)
    end do
    do square = 0, 15
      castle_keys(square) = next_key(stream)
    end do
    black_key = next_key(stream)
    initialized = .true.
  end subroutine initialize_keys

  integer(int64) function next_key(stream) result(key)
    integer(int64), intent(inout) :: stream

    stream = ieor(stream, shiftl(stream, 13))
    stream = ieor(stream, shiftr(stream, 7))
    stream = ieor(stream, shiftl(stream, 17))
    key = stream
  end function next_key

  pure integer(int64) function state_key(turn, castling, ep) result(key)
    integer, intent(in) :: turn, castling, ep

    key = castle_keys(castling)
    if (turn == black) key = ieor(key, black_key)
    if (ep >= 0) key = ieor(key, ep_keys(ep))
  end function state_key

  pure integer(int64) function extend_history_key(previous, current) result(key)
    integer(int64), intent(in) :: previous, current
    integer(int64), parameter :: low_mask = int(z'FFFFFFFF', int64)
    integer(int64) :: rotated, low, high

    ! Add modulo 2**64 in two limbs to avoid signed integer overflow.
    rotated = ishftc(previous, 11)
    low = iand(rotated, low_mask) + iand(current, low_mask)
    high = shiftr(rotated, 32) + shiftr(current, 32) + shiftr(low, 32)
    key = ieor(ior(shiftl(high, 32), iand(low, low_mask)), ishftc(previous, 37))
  end function extend_history_key

end module chess_hashes
