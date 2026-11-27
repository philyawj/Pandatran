module chess_moves
  use, intrinsic :: iso_fortran_env, only: int32
  implicit none
  private

  integer, parameter, public :: no_square = -1
  integer, parameter, public :: white = 1, black = 2
  integer, parameter, public :: pawn = 1, knight = 2, bishop = 3, rook = 4, queen = 5, king = 6
  integer, parameter, public :: king_side(2) = [1, 4], queen_side(2) = [2, 8]
  integer, parameter, public :: home_king(2) = [4, 60], pawn_step(2) = [8, -8]
  integer, parameter, public :: max_moves = 512
  character(len=8), parameter :: files = 'abcdefgh', ranks = '12345678'
  character(len=6), parameter :: piece_letters = 'pnbrqk'

  public :: pack_move, move_from, move_to, move_promotion, move_text, parse_move
  public :: square_text, parse_square, other_side, piece_side, colored_piece

contains

  pure integer(int32) function pack_move(origin, target, promotion) result(move)
    integer, intent(in) :: origin, target
    integer, intent(in), optional :: promotion

    move = ior(int(origin, int32), shiftl(int(target, int32), 6))
    if (present(promotion)) move = ior(move, shiftl(int(promotion, int32), 12))
  end function pack_move

  pure integer function move_from(move) result(origin)
    integer(int32), intent(in) :: move
    origin = int(ibits(move, 0, 6))
  end function move_from

  pure integer function move_to(move) result(target)
    integer(int32), intent(in) :: move
    target = int(ibits(move, 6, 6))
  end function move_to

  pure integer function move_promotion(move) result(promotion)
    integer(int32), intent(in) :: move
    promotion = int(ibits(move, 12, 3))
  end function move_promotion

  pure function square_text(square) result(text)
    integer, intent(in) :: square
    character(len=2) :: text
    integer :: file, rank

    file = mod(square, 8) + 1
    rank = square / 8 + 1
    text = files(file:file) // ranks(rank:rank)
  end function square_text

  pure integer function parse_square(text) result(square)
    character(len=*), intent(in) :: text
    integer :: file, rank

    square = no_square
    if (len(text) /= 2) return
    file = index(files, text(1:1))
    rank = index(ranks, text(2:2))
    if (file > 0 .and. rank > 0) square = 8 * (rank - 1) + file - 1
  end function parse_square

  pure function move_text(move) result(text)
    integer(int32), intent(in) :: move
    character(len=5) :: text
    integer :: promotion

    text = square_text(move_from(move)) // square_text(move_to(move))
    promotion = move_promotion(move)
    if (promotion /= 0) text(5:5) = piece_letters(promotion:promotion)
  end function move_text

  logical function parse_move(text, move) result(ok)
    character(len=*), intent(in) :: text
    integer(int32), intent(out) :: move
    integer :: origin, target, promotion

    ok = .false.
    move = 0_int32
    if (len_trim(text) < 4 .or. len_trim(text) > 5) return
    origin = parse_square(text(1:2))
    target = parse_square(text(3:4))
    if (origin == no_square .or. target == no_square .or. origin == target) return
    promotion = 0
    if (len_trim(text) == 5) then
      promotion = index(piece_letters, text(5:5))
      if (promotion < knight .or. promotion > queen) return
    end if
    move = pack_move(origin, target, promotion)
    ok = .true.
  end function parse_move

  pure integer function other_side(side) result(opponent)
    integer, intent(in) :: side
    opponent = white + black - side
  end function other_side

  pure integer function piece_side(piece) result(side)
    integer, intent(in) :: piece
    side = merge(white, black, piece > 0)
  end function piece_side

  pure integer function colored_piece(kind, side) result(piece)
    integer, intent(in) :: kind, side
    piece = merge(kind, -kind, side == white)
  end function colored_piece

end module chess_moves
