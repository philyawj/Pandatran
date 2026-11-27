module chess_positions
  use, intrinsic :: iso_fortran_env, only: int32, int64
  use chess_moves
  use chess_hashes, only: initialize_keys, piece_keys, state_key
  implicit none
  private

  character(len=*), parameter, public :: start_fen = &
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
  character(len=12), parameter :: fen_pieces = 'PNBRQKpnbrqk'
  character(len=4), parameter :: fen_rights = 'KQkq'
  character(len=10), parameter :: digits = '0123456789'

  type, public :: position
    ! Squares run from a1 = 0 to h8 = 63. White pieces are positive and black pieces are negative.
    integer :: board(0:63) = 0
    integer(int64) :: pieces(6, 2) = 0_int64, occupied(2) = 0_int64
    integer :: turn = white, castling = 0, ep = no_square
    integer(int64) :: halfmove = 0_int64, fullmove = 1_int64, key = 0_int64
  end type position

  type, public :: undo_state
    private
    integer :: captured, capture_square, castling, ep
    integer(int64) :: halfmove, fullmove
  end type undo_state

  public :: parse_fen, to_fen, make_move, unmake_move, recompute_key

contains

  logical function parse_fen(fen, pos) result(ok)
    character(len=*), intent(in) :: fen
    type(position), intent(inout) :: pos
    type(position) :: candidate
    integer :: first, last, field
    logical :: valid

    ok = .false.
    call initialize_keys()
    candidate = position()
    last = 0
    do field = 1, 6
      first = last + 1
      do while (first <= len(fen))
        if (.not. whitespace(fen(first:first))) exit
        first = first + 1
      end do
      last = first
      do while (last <= len(fen))
        if (whitespace(fen(last:last))) exit
        last = last + 1
      end do
      if (first == last) return
      valid = read_field(fen(first:last-1), field, candidate)
      if (.not. valid) return
    end do
    do first = last, len(fen)
      if (.not. whitespace(fen(first:first))) return
    end do
    candidate%key = ieor(candidate%key, state_key(candidate%turn, candidate%castling, candidate%ep))
    pos = candidate
    ok = .true.
  end function parse_fen

  logical function read_field(token, field, pos) result(ok)
    character(len=*), intent(in) :: token
    integer, intent(in) :: field
    type(position), intent(inout) :: pos
    integer :: i, bit, square, step

    ok = .false.
    select case (field)
    case (1)
      if (.not. read_placement(token, pos)) return
    case (2)
      select case (token)
      case ('w')
        pos%turn = white
      case ('b')
        pos%turn = black
      case default
        return
      end select
    case (3)
      if (token /= '-') then
        do i = 1, len(token)
          bit = index(fen_rights, token(i:i)) - 1
          if (bit < 0) return
          if (btest(pos%castling, bit)) return
          pos%castling = ibset(pos%castling, bit)
        end do
        do i = white, black
          square = home_king(i)
          if (iand(pos%castling, ior(king_side(i), queen_side(i))) == 0) cycle
          if (pos%board(square) /= colored_piece(king, i)) return
          if (iand(pos%castling, king_side(i)) /= 0) then
            if (pos%board(square + 3) /= colored_piece(rook, i)) return
          end if
          if (iand(pos%castling, queen_side(i)) /= 0) then
            if (pos%board(square - 4) /= colored_piece(rook, i)) return
          end if
        end do
      end if
    case (4)
      if (token /= '-') then
        square = parse_square(token)
        if (square == no_square) return
        if (square / 8 /= merge(5, 2, pos%turn == white)) return
        step = pawn_step(pos%turn)
        if (pos%board(square) /= 0 .or. pos%board(square + step) /= 0) return
        if (pos%board(square - step) /= colored_piece(pawn, other_side(pos%turn))) return
        pos%ep = square
      end if
    case (5)
      if (.not. read_counter(token, pos%halfmove)) return
    case (6)
      if (.not. read_counter(token, pos%fullmove)) return
      if (pos%fullmove == 0) return
    end select
    ok = .true.
  end function read_field

  logical function read_placement(token, pos) result(ok)
    character(len=*), intent(in) :: token
    type(position), intent(inout) :: pos
    integer :: file, rank, i, piece, empty_count
    logical :: previous_was_digit

    ok = .false.
    file = 0
    rank = 7
    previous_was_digit = .false.
    do i = 1, len(token)
      if (token(i:i) == '/') then
        if (file /= 8 .or. rank == 0) return
        rank = rank - 1
        file = 0
        previous_was_digit = .false.
        cycle
      end if
      if (file >= 8) return
      piece = index(fen_pieces, token(i:i))
      if (piece > 0) then
        if (piece > 6) piece = 6 - piece
        if (abs(piece) == pawn .and. (rank == 0 .or. rank == 7)) return
        call put_piece(pos, 8 * rank + file, piece)
        file = file + 1
        previous_was_digit = .false.
      else
        empty_count = index(digits, token(i:i)) - 1
        if (empty_count < 1 .or. empty_count > 8 .or. previous_was_digit) return
        file = file + empty_count
        previous_was_digit = .true.
      end if
    end do
    if (rank /= 0 .or. file /= 8) return
    if (any(popcnt(pos%pieces(king, :)) /= 1)) return
    if (any(popcnt(pos%pieces(pawn, :)) > 8) .or. any(popcnt(pos%occupied) > 16)) return
    ok = .true.
  end function read_placement

  logical function read_counter(token, value) result(ok)
    character(len=*), intent(in) :: token
    integer(int64), intent(out) :: value
    integer :: i, digit

    ok = .false.
    value = 0_int64
    do i = 1, len(token)
      digit = index(digits, token(i:i)) - 1
      if (digit < 0) return
      if (value > (huge(value) - digit) / 10) return
      value = 10 * value + digit
    end do
    ok = .true.
  end function read_counter

  pure logical function whitespace(c) result(space)
    character, intent(in) :: c
    space = c == ' ' .or. c == achar(9)
  end function whitespace

  function to_fen(pos) result(fen)
    type(position), intent(in) :: pos
    character(len=:), allocatable :: fen
    character(len=71) :: placement
    character(len=4) :: rights
    character(len=20) :: halfmove, fullmove
    integer :: rank, file, length, blanks, piece, i, rights_count

    length = 0
    do rank = 7, 0, -1
      blanks = 0
      do file = 0, 7
        piece = pos%board(8 * rank + file)
        if (piece == 0) then
          blanks = blanks + 1
          cycle
        end if
        call append_blanks()
        if (piece < 0) piece = 6 - piece
        length = length + 1
        placement(length:length) = fen_pieces(piece:piece)
      end do
      call append_blanks()
      if (rank > 0) then
        length = length + 1
        placement(length:length) = '/'
      end if
    end do

    rights = '-'
    rights_count = 0
    do i = 1, 4
      if (.not. btest(pos%castling, i - 1)) cycle
      rights_count = rights_count + 1
      rights(rights_count:rights_count) = fen_rights(i:i)
    end do
    fen = placement(:length) // merge(' w ', ' b ', pos%turn == white) // trim(rights)
    if (pos%ep == no_square) then
      fen = fen // ' -'
    else
      fen = fen // ' ' // square_text(pos%ep)
    end if
    write (halfmove, '(i0)') pos%halfmove
    write (fullmove, '(i0)') pos%fullmove
    fen = fen // ' ' // trim(halfmove) // ' ' // trim(fullmove)

  contains

    subroutine append_blanks()
      if (blanks == 0) return
      length = length + 1
      placement(length:length) = digits(blanks+1:blanks+1)
      blanks = 0
    end subroutine append_blanks

  end function to_fen

  ! The caller supplies a pseudo-legal move from this position.
  subroutine make_move(pos, move, undo)
    type(position), intent(inout) :: pos
    integer(int32), intent(in) :: move
    type(undo_state), intent(out) :: undo
    integer :: origin, target, piece, promotion, step, captured_square

    origin = move_from(move)
    target = move_to(move)
    promotion = move_promotion(move)
    piece = pos%board(origin)
    step = pawn_step(pos%turn)
    captured_square = target
    if (abs(piece) == pawn .and. target == pos%ep) captured_square = target - step
    undo = undo_state(pos%board(captured_square), captured_square, pos%castling, pos%ep, pos%halfmove, pos%fullmove)

    pos%key = ieor(pos%key, state_key(pos%turn, pos%castling, pos%ep))
    if (undo%captured /= 0) call remove_piece(pos, captured_square)
    call remove_piece(pos, origin)
    if (promotion == 0) then
      call put_piece(pos, target, piece)
    else
      call put_piece(pos, target, colored_piece(promotion, pos%turn))
    end if
    if (abs(piece) == king .and. abs(target - origin) == 2) call move_castle_rook(pos, origin, target, .false.)
    call clear_castling(pos, origin)
    if (undo%captured /= 0) call clear_castling(pos, captured_square)

    pos%ep = no_square
    if (abs(piece) == pawn .and. target - origin == 2 * step) pos%ep = origin + step
    if (abs(piece) == pawn .or. undo%captured /= 0) then
      pos%halfmove = 0_int64
    else if (pos%halfmove < huge(pos%halfmove)) then
      pos%halfmove = pos%halfmove + 1
    end if
    if (pos%turn == black .and. pos%fullmove < huge(pos%fullmove)) pos%fullmove = pos%fullmove + 1
    pos%turn = other_side(pos%turn)
    pos%key = ieor(pos%key, state_key(pos%turn, pos%castling, pos%ep))
  end subroutine make_move

  subroutine unmake_move(pos, move, undo)
    type(position), intent(inout) :: pos
    integer(int32), intent(in) :: move
    type(undo_state), intent(in) :: undo
    integer :: origin, target, piece

    origin = move_from(move)
    target = move_to(move)
    pos%key = ieor(pos%key, state_key(pos%turn, pos%castling, pos%ep))
    pos%turn = other_side(pos%turn)
    piece = pos%board(target)
    if (move_promotion(move) /= 0) piece = colored_piece(pawn, pos%turn)
    if (abs(piece) == king .and. abs(target - origin) == 2) call move_castle_rook(pos, origin, target, .true.)
    call remove_piece(pos, target)
    call put_piece(pos, origin, piece)
    if (undo%captured /= 0) call put_piece(pos, undo%capture_square, undo%captured)
    pos%castling = undo%castling
    pos%ep = undo%ep
    pos%halfmove = undo%halfmove
    pos%fullmove = undo%fullmove
    pos%key = ieor(pos%key, state_key(pos%turn, pos%castling, pos%ep))
  end subroutine unmake_move

  subroutine move_castle_rook(pos, origin, target, reverse)
    type(position), intent(inout) :: pos
    integer, intent(in) :: origin, target
    logical, intent(in) :: reverse
    integer :: corner, transit

    corner = origin + merge(3, -4, target > origin)
    transit = (origin + target) / 2
    if (reverse) then
      call remove_piece(pos, transit)
      call put_piece(pos, corner, colored_piece(rook, pos%turn))
    else
      call remove_piece(pos, corner)
      call put_piece(pos, transit, colored_piece(rook, pos%turn))
    end if
  end subroutine move_castle_rook

  subroutine clear_castling(pos, square)
    type(position), intent(inout) :: pos
    integer, intent(in) :: square
    integer :: mask

    select case (square)
    case (0)
      mask = queen_side(white)
    case (4)
      mask = ior(king_side(white), queen_side(white))
    case (7)
      mask = king_side(white)
    case (56)
      mask = queen_side(black)
    case (60)
      mask = ior(king_side(black), queen_side(black))
    case (63)
      mask = king_side(black)
    case default
      return
    end select
    pos%castling = iand(pos%castling, not(mask))
  end subroutine clear_castling

  subroutine put_piece(pos, square, piece)
    type(position), intent(inout) :: pos
    integer, intent(in) :: square, piece
    integer :: side, kind

    side = piece_side(piece)
    kind = abs(piece)
    pos%board(square) = piece
    pos%key = ieor(pos%key, piece_keys(square, piece))
    pos%pieces(kind, side) = ibset(pos%pieces(kind, side), square)
    pos%occupied(side) = ibset(pos%occupied(side), square)
  end subroutine put_piece

  subroutine remove_piece(pos, square)
    type(position), intent(inout) :: pos
    integer, intent(in) :: square
    integer :: side, kind

    side = piece_side(pos%board(square))
    kind = abs(pos%board(square))
    pos%key = ieor(pos%key, piece_keys(square, pos%board(square)))
    pos%board(square) = 0
    pos%pieces(kind, side) = ibclr(pos%pieces(kind, side), square)
    pos%occupied(side) = ibclr(pos%occupied(side), square)
  end subroutine remove_piece

  pure integer(int64) function recompute_key(pos) result(key)
    type(position), intent(in) :: pos
    integer :: square

    key = state_key(pos%turn, pos%castling, pos%ep)
    do square = 0, 63
      key = ieor(key, piece_keys(square, pos%board(square)))
    end do
  end function recompute_key

end module chess_positions
