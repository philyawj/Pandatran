module chess_evaluation
  use, intrinsic :: iso_fortran_env, only: int64
  use chess_moves, only: white, black, pawn, knight, bishop, rook, queen, king, other_side, pawn_step
  use chess_positions, only: position
  use chess_movegen, only: piece_targets, pawn_pressure
  implicit none
  private

  integer, parameter, public :: legacy_eval = -1, tapered_eval = 0
  integer, parameter, public :: pawns_eval = 1, mobility_eval = 2, safety_eval = 4
  integer, parameter :: all_eval = pawns_eval + mobility_eval + safety_eval
  integer, parameter, public :: default_eval = all_eval
  integer, parameter, public :: ordering_values(6) = [100, 320, 330, 500, 900, 0]
  integer, parameter :: mg_values(6) = [100, 320, 335, 500, 930, 0]
  integer, parameter :: eg_values(6) = [120, 305, 335, 525, 940, 0]
  integer, parameter :: phase_weights(6) = [0, 1, 1, 2, 4, 0], max_phase = 24
  integer(int64), parameter :: file_a = int(z'0101010101010101', int64)
  integer :: file
  integer(int64), parameter :: files(0:7) = [(shiftl(file_a, file), file=0,7)]
  integer(int64), parameter :: adjacent(0:7) = ior( &
    shiftr(iand(files, not(files(0))), 1), shiftl(iand(files, not(files(7))), 1))

  public :: evaluate, evaluation_profile, game_phase

contains

  pure integer function evaluation_profile(name) result(profile)
    character(len=*), intent(in) :: name

    select case (name)
    case ('default')
      profile = default_eval
    case ('legacy')
      profile = legacy_eval
    case ('tapered')
      profile = tapered_eval
    case ('pawns')
      profile = pawns_eval
    case ('mobility')
      profile = mobility_eval
    case ('safety')
      profile = safety_eval
    case ('pawns+mobility')
      profile = pawns_eval + mobility_eval
    case ('pawns+safety')
      profile = pawns_eval + safety_eval
    case ('mobility+safety')
      profile = mobility_eval + safety_eval
    case ('all')
      profile = all_eval
    case default
      profile = -2
    end select
  end function evaluation_profile

  pure integer function game_phase(pos) result(phase)
    type(position), intent(in) :: pos

    phase = min(max_phase, sum(sum(popcnt(pos%pieces), dim=2) * phase_weights))
  end function game_phase

  pure integer function evaluate(pos, profile) result(score)
    type(position), intent(in) :: pos
    integer, intent(in) :: profile
    integer :: phase, white_score(2), black_score(2), balance(2)

    if (profile == legacy_eval) then
      score = legacy_evaluate(pos)
      return
    end if

    phase = game_phase(pos)
    white_score = evaluate_side(pos, white, profile)
    black_score = evaluate_side(pos, black, profile)
    balance = white_score - black_score
    score = (balance(1) * phase + balance(2) * (max_phase - phase)) / max_phase
    if (pos%turn == black) score = -score
  end function evaluate

  pure function evaluate_side(pos, side, profile) result(value)
    type(position), intent(in) :: pos
    integer, intent(in) :: side, profile
    integer :: value(2), kind, count, square, rank, col
    integer(int64) :: ours, theirs, occupied, safe, pieces

    value = 0
    ours = pos%pieces(pawn, side)
    theirs = pos%pieces(pawn, other_side(side))
    occupied = ior(pos%occupied(white), pos%occupied(black))
    safe = 0_int64
    if (iand(profile, mobility_eval) /= 0) safe = not(ior(pos%occupied(side), pawn_pressure(theirs, other_side(side))))

    do kind = pawn, king
      pieces = pos%pieces(kind, side)
      count = popcnt(pieces)
      value = value + count * [mg_values(kind), eg_values(kind)]
      do while (pieces /= 0)
        square = trailz(pieces)
        pieces = ibclr(pieces, square)
        col = mod(square, 8)
        rank = square / 8
        if (side == black) rank = 7 - rank
        value = value + placement(kind, col, rank)
        if (iand(profile, mobility_eval) /= 0 .and. kind >= knight .and. kind <= queen) then
          value = value + mobility(kind, square, occupied, safe)
        end if
      end do
    end do

    if (iand(profile, pawns_eval) /= 0) value = value + pawn_structure(ours, theirs, occupied, side)
    if (iand(profile, safety_eval) /= 0) value(1) = value(1) + king_shelter(pos, side, ours, theirs)
  end function evaluate_side

  pure function placement(kind, col, rank) result(value)
    integer, intent(in) :: kind, col, rank
    integer :: value(2), file_center, center, castled_file

    file_center = min(col, 7 - col)
    center = file_center + min(rank, 7 - rank)
    value = 0
    select case (kind)
    case (pawn)
      value = [4 * rank + 4 * file_center, 8 * rank + 2 * file_center]
    case (knight)
      value = [12 * center - merge(8, 0, rank == 0), 8 * center]
    case (bishop)
      value = [6 * center + merge(6, 0, rank > 0), 5 * center]
    case (rook)
      value = [2 * rank + merge(12, 0, rank == 6), 4 * rank + merge(8, 0, rank == 6)]
    case (queen)
      value = [3 * center - 4 * max(0, rank - 2), 6 * center]
    case (king)
      castled_file = merge(14, 0, rank == 0 .and. (col == 1 .or. col == 2 .or. col == 6))
      value = [castled_file - 10 * center, 12 * center]
    end select
  end function placement

  pure function pawn_structure(ours, theirs, occupied, side) result(value)
    integer(int64), intent(in) :: ours, theirs, occupied
    integer, intent(in) :: side
    integer :: value(2), col, square, rank, excess, bonus(2)
    integer, parameter :: mg_passer(0:7) = [0, 0, 3, 8, 15, 27, 47, 0]
    integer, parameter :: eg_passer(0:7) = [0, 5, 12, 24, 44, 72, 105, 0]
    integer(int64) :: open_ahead, scan

    value = 0
    do col = 0, 7
      excess = max(0, popcnt(iand(ours, files(col))) - 1)
      value = value - excess * [11, 17]
    end do
    scan = ours
    do while (scan /= 0)
      square = trailz(scan)
      scan = ibclr(scan, square)
      col = mod(square, 8)
      rank = square / 8
      if (iand(ours, adjacent(col)) == 0) value = value - [10, 14]
      if (side == white) then
        open_ahead = shiftl(not(0_int64), 8 * (rank + 1))
      else
        open_ahead = shiftr(not(0_int64), 8 * (8 - rank))
        rank = 7 - rank
      end if
      if (iand(iand(theirs, ior(files(col), adjacent(col))), open_ahead) /= 0) cycle
      bonus = [mg_passer(rank), eg_passer(rank)]
      if (btest(occupied, square + pawn_step(side))) bonus = bonus / 2
      value = value + bonus
    end do
  end function pawn_structure

  pure function mobility(kind, square, occupied, safe) result(value)
    integer, intent(in) :: kind, square
    integer(int64), intent(in) :: occupied, safe
    integer :: value(2), targets
    integer, parameter :: mg(knight:queen) = [4, 4, 2, 1], eg(knight:queen) = [3, 3, 3, 2]

    targets = popcnt(iand(piece_targets(square, kind, occupied), safe))
    value = targets * [mg(kind), eg(kind)]
  end function mobility

  pure integer function king_shelter(pos, side, ours, theirs) result(score)
    type(position), intent(in) :: pos
    integer, intent(in) :: side
    integer(int64), intent(in) :: ours, theirs
    integer :: square, col, rank, step, neighbor, line, distance, attacker, danger

    attacker = other_side(side)
    danger = min(12, 4 * popcnt(pos%pieces(queen, attacker)) + 2 * popcnt(pos%pieces(rook, attacker)) + &
      sum(popcnt(pos%pieces(knight:bishop, attacker))))
    score = 0
    if (danger == 0) return
    square = trailz(pos%pieces(king, side))
    col = mod(square, 8)
    rank = square / 8
    step = merge(1, -1, side == white)
    do neighbor = max(0, col - 1), min(7, col + 1)
      if (iand(ours, files(neighbor)) == 0) score = score - 9
      do distance = 1, 2
        line = rank + step * distance
        if (line < 0 .or. line > 7) exit
        if (btest(ours, 8 * line + neighbor)) score = score + merge(12, 6, distance == 1)
        if (btest(theirs, 8 * line + neighbor)) score = score - merge(16, 9, distance == 1)
      end do
    end do
    score = score * danger / 12
  end function king_shelter

  pure integer function legacy_evaluate(pos) result(score)
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
      score = score + sign(1, piece) * (ordering_values(kind) + placement)
    end do
    if (pos%turn /= white) score = -score
  end function legacy_evaluate

end module chess_evaluation
