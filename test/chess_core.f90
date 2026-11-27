program chess_core
  use, intrinsic :: iso_fortran_env, only: error_unit, int32, int64
  use chess_moves
  use chess_positions
  use chess_movegen
  use chess_perft
  implicit none

  character(len=*), parameter :: kiwipete = &
    'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1'
  character(len=*), parameter :: position3 = '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1'
  character(len=*), parameter :: castle_fen = 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 7 12'
  character(len=*), parameter :: ep_fen = '4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2'
  type(position) :: pos, original
  type(move_list) :: list
  integer(int32) :: move
  integer :: i
  integer(int64) :: rng
  logical :: ok

  call load(start_fen, pos)
  original = pos
  call require(to_fen(pos) == start_fen, 'start FEN round trip')
  call load('4k3/8/8/8/4P3/8/8/4K3 b - e3 0 1', pos)
  call require(to_fen(pos) == '4k3/8/8/8/4P3/8/8/4K3 b - e3 0 1', 'en passant target without a capturer')
  call reject_fen(start_fen // ' extra', original)
  call reject_fen('4k3/8/8/8/8/8/8/4K3 w - - 0', original)
  call reject_fen('4k3/8/8/8/8/8/8/4K3 x - - 0 1', original)
  call reject_fen('4k3/8/8/8/8/8/8/4K3 w K - 0 1', original)
  call reject_fen('r3k2r/8/8/8/8/8/8/R3K2R w KK - 0 1', original)
  call reject_fen('4k3/8/8/8/8/8/8/4K3 w - e6 0 1', original)
  call reject_fen('4k3/8/8/8/8/8/8/4K3 w - - -1 1', original)
  call reject_fen('4k3/8/8/8/8/8/8/4K3 w - - 0 0', original)
  call reject_fen('4k3/8/8/8/8/8/8/4K3 w - - 9223372036854775808 1', original)
  call reject_fen('8/8/8/8/8/8/8/4K3 w - - 0 1', original)
  call reject_fen('4k3/8/8/8/8/8/8/4K2P w - - 0 1', original)
  call reject_fen('4k3/8/8/8/8/8/8/4K4 w - - 0 1', original)
  call reject_fen('4k3/8/8/8/8/8/44/4K3 w - - 0 1', original)

  call require(parse_square('a1') == 0 .and. parse_square('h8') == 63, 'square convention')
  ok = parse_move('a7b8n', move)
  call require(ok, 'parse a promotion')
  call require(move_from(move) == 48 .and. move_to(move) == 57, 'packed move squares')
  call require(move_promotion(move) == knight .and. move_text(move) == 'a7b8n', 'promotion round trip')
  ok = parse_move('a7a8k', move)
  call require(.not. ok, 'reject king promotion')
  ok = parse_move('a0a1', move)
  call require(.not. ok, 'reject invalid square')

  call expect_transition(start_fen, 'e2e4', &
    'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1')
  call expect_transition(castle_fen, 'e1g1', 'r3k2r/8/8/8/8/8/8/R4RK1 b kq - 8 12')
  call expect_transition(castle_fen, 'e1c1', 'r3k2r/8/8/8/8/8/8/2KR3R b kq - 8 12')
  call expect_transition('r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 7 12', 'e8c8', &
    '2kr3r/8/8/8/8/8/8/R3K2R w KQ - 8 13')
  call expect_transition(castle_fen, 'a1a8', 'R3k2r/8/8/8/8/8/8/4K2R b Kk - 0 12')
  call expect_transition(ep_fen, 'e5d6', '4k3/8/3P4/8/8/8/8/4K3 b - - 0 2')
  call expect_transition('4k3/8/8/8/3pP3/8/8/4K3 b - e3 0 30', 'd4e3', &
    '4k3/8/8/8/8/4p3/8/4K3 w - - 0 31')
  call expect_transition('1r2k3/P7/8/8/8/8/8/4K3 w - - 4 1', 'a7b8q', &
    '1Q2k3/8/8/8/8/8/8/4K3 b - - 0 1')
  call expect_transition('4k3/8/8/8/8/8/p7/1R2K3 b - - 4 1', 'a2b1n', &
    '4k3/8/8/8/8/8/8/1n2K3 w - - 0 2')

  call expect_move('1k3r2/8/8/8/8/8/8/R3K2R w KQ - 0 1', 'e1g1', .false.)
  call expect_move('1k3r2/8/8/8/8/8/8/R3K2R w KQ - 0 1', 'e1c1', .true.)
  call expect_move('1k2r3/8/8/8/8/8/8/R3K2R w KQ - 0 1', 'e1c1', .false.)
  call expect_move('1k4r1/8/8/8/8/8/8/R3K2R w KQ - 0 1', 'e1g1', .false.)
  call expect_move('1k6/8/8/8/8/8/8/RN2K2R w KQ - 0 1', 'e1c1', .false.)
  call expect_move('k3r3/8/8/3pP3/8/8/8/4K3 w - d6 0 2', 'e5d6', .false.)
  call expect_move('8/8/8/r4pPK/8/8/8/4k3 w - f6 0 2', 'g5f6', .false.)
  call expect_move('k3r3/8/8/8/8/8/4R3/4K3 w - - 0 1', 'e2d2', .false.)
  call expect_move('k3r3/8/8/8/8/8/4R3/4K3 w - - 0 1', 'e2e3', .true.)
  call load('1r2k3/P7/8/8/8/8/8/4K3 w - - 0 1', pos)
  call generate_legal(pos, list)
  do i = knight, queen
    call require(any(list%moves(:list%count) == pack_move(48, 56, i)), 'missing quiet promotion')
    call require(any(list%moves(:list%count) == pack_move(48, 57, i)), 'missing capture promotion')
  end do
  call require(.not. any(list%moves(:list%count) == pack_move(48, 56)), 'missing promotion suffix')
  call load('k3r3/8/8/8/1b6/8/8/N3K3 w - - 0 1', pos)
  call generate_legal(pos, list)
  call require(in_check(pos, white) .and. list%count > 0, 'double check with legal escapes')
  do i = 1, list%count
    call require(move_from(list%moves(i)) == 4, 'non-king evasion in double check')
  end do
  call expect_terminal('7k/5K2/6Q1/8/8/8/8/8 b - - 0 1', .false.)
  call expect_terminal('7k/6Q1/5K2/8/8/8/8/8 b - - 0 1', .true.)

  call expect_perft(start_fen, 0, 1_int64)
  call expect_perft(start_fen, 4, 197281_int64)
  call expect_perft(kiwipete, 3, 97862_int64)
  call expect_perft(position3, 4, 43238_int64)
  call expect_perft('r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1', 3, 9467_int64)
  call expect_perft('rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8', 3, 62379_int64)
  call expect_perft('r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10', 3, 89890_int64)
  call expect_divide(start_fen, 'e2e4', 3, 600_int64, 8902_int64)
  call expect_divide(kiwipete, 'e1g1', 2, 43_int64, 2039_int64)

  rng = 329891_int64
  call walk(start_fen, rng)
  call walk(kiwipete, rng)
  call walk(position3, rng)
  call walk(castle_fen, rng)
  call walk(ep_fen, rng)

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (condition) return
    write (error_unit, '(a)') message
    stop 1
  end subroutine require

  subroutine load(fen, current)
    character(len=*), intent(in) :: fen
    type(position), intent(inout) :: current
    logical :: valid

    valid = parse_fen(fen, current)
    call require(valid, 'Rejected FEN: ' // fen)
    call check_bitboards(current, fen)
  end subroutine load

  subroutine reject_fen(fen, base)
    character(len=*), intent(in) :: fen
    type(position), intent(in) :: base
    type(position) :: current
    logical :: valid

    current = base
    valid = parse_fen(fen, current)
    call require(.not. valid, 'Accepted invalid FEN: ' // fen)
    call same_state(current, base, 'failed parse changed state: ' // fen)
  end subroutine reject_fen

  subroutine expect_move(fen, text, expected)
    character(len=*), intent(in) :: fen, text
    logical, intent(in) :: expected
    type(position) :: current, before
    type(move_list) :: legal
    integer(int32) :: packed
    logical :: valid, found

    call load(fen, current)
    before = current
    valid = parse_move(text, packed)
    call require(valid, 'Bad test move: ' // text)
    call generate_legal(current, legal)
    found = any(legal%moves(:legal%count) == packed)
    call require(found .eqv. expected, 'Wrong legality for ' // text // ' in ' // fen)
    call same_state(current, before, 'generation changed state for ' // text)
  end subroutine expect_move

  subroutine expect_transition(fen, text, expected)
    character(len=*), intent(in) :: fen, text, expected
    type(position) :: current, before
    type(undo_state) :: undo
    integer(int32) :: packed
    logical :: valid

    call expect_move(fen, text, .true.)
    call load(fen, current)
    before = current
    valid = parse_move(text, packed)
    call require(valid, 'Bad transition move: ' // text)
    call make_move(current, packed, undo)
    call require(to_fen(current) == expected, 'Wrong FEN after ' // text // ': ' // to_fen(current))
    call check_bitboards(current, text)
    call unmake_move(current, packed, undo)
    call same_state(current, before, 'undo after ' // text)
  end subroutine expect_transition

  subroutine expect_terminal(fen, checked)
    character(len=*), intent(in) :: fen
    logical, intent(in) :: checked
    type(position) :: current
    type(move_list) :: legal
    integer(int64) :: nodes

    call load(fen, current)
    call generate_legal(current, legal)
    call require(legal%count == 0, 'legal moves in terminal FEN: ' // fen)
    call require(in_check(current, current%turn) .eqv. checked, 'wrong terminal check state: ' // fen)
    nodes = perft(current, 1)
    call require(nodes == 0, 'terminal perft: ' // fen)
  end subroutine expect_terminal

  subroutine expect_perft(fen, depth, expected)
    character(len=*), intent(in) :: fen
    integer, intent(in) :: depth
    integer(int64), intent(in) :: expected
    type(position) :: current, before
    integer(int64) :: nodes
    character(len=100) :: details

    call load(fen, current)
    before = current
    nodes = perft(current, depth)
    write (details, '("depth ",i0,", expected ",i0,", got ",i0)') depth, expected, nodes
    call require(nodes == expected, trim(details) // ' in ' // fen)
    call same_state(current, before, 'perft changed state: ' // fen)
  end subroutine expect_perft

  subroutine expect_divide(fen, text, depth, branch, total)
    character(len=*), intent(in) :: fen, text
    integer, intent(in) :: depth
    integer(int64), intent(in) :: branch, total
    type(position) :: current, before
    type(move_list) :: legal
    integer(int64) :: counts(max_moves)
    integer :: index
    logical :: found

    call load(fen, current)
    before = current
    call perft_divide(current, depth, legal, counts)
    call require(sum(counts(:legal%count)) == total, 'divide total in ' // fen)
    found = .false.
    do index = 1, legal%count
      if (move_text(legal%moves(index)) /= text) cycle
      call require(counts(index) == branch, 'divide branch ' // text // ' in ' // fen)
      found = .true.
    end do
    call require(found, 'divide missing ' // text // ' in ' // fen)
    call same_state(current, before, 'divide changed state: ' // fen)
  end subroutine expect_divide

  subroutine walk(fen, seed)
    character(len=*), intent(in) :: fen
    integer(int64), intent(inout) :: seed
    integer, parameter :: length = 120
    type(position) :: current, snapshots(0:length), roundtrip
    type(undo_state) :: history(length)
    integer(int32) :: moves(length)
    type(move_list) :: legal
    integer :: ply, game, index, count
    character(len=80) :: context

    do game = 1, 4
      call load(fen, current)
      snapshots(0) = current
      count = 0
      do ply = 1, length
        write (context, '("walk ",i0," ply ",i0," seed ",i0)') game, ply, seed
        call generate_legal(current, legal)
        call same_state(current, snapshots(ply - 1), trim(context) // ' generate')
        if (legal%count == 0) exit
        seed = modulo(48271_int64 * seed, 2147483647_int64)
        index = 1 + int(modulo(seed, int(legal%count, int64)))
        moves(ply) = legal%moves(index)
        call make_move(current, moves(ply), history(ply))
        count = ply
        snapshots(ply) = current
        call load(to_fen(current), roundtrip)
        call same_state(current, roundtrip, trim(context) // ' ' // move_text(moves(ply)) // ' FEN round trip')
      end do
      do ply = count, 1, -1
        write (context, '("walk ",i0," undo ply ",i0)') game, ply
        call unmake_move(current, moves(ply), history(ply))
        call same_state(current, snapshots(ply - 1), trim(context) // ' ' // move_text(moves(ply)))
      end do
    end do
  end subroutine walk

  subroutine check_bitboards(current, label)
    type(position), intent(in) :: current
    character(len=*), intent(in) :: label
    integer(int64) :: pieces(6, 2), occupancy(2)
    integer :: square, piece, side

    pieces = 0_int64
    do square = 0, 63
      piece = current%board(square)
      if (piece == 0) cycle
      side = piece_side(piece)
      pieces(abs(piece), side) = ibset(pieces(abs(piece), side), square)
    end do
    occupancy = iany(pieces, dim=1)
    call require(all(current%pieces == pieces), label // ' piece bitboards')
    call require(all(current%occupied == occupancy), label // ' occupancy')
  end subroutine check_bitboards

  subroutine same_state(current, expected, label)
    type(position), intent(in) :: current, expected
    character(len=*), intent(in) :: label

    call require(all(current%board == expected%board), label // ' board')
    call require(all(current%pieces == expected%pieces), label // ' pieces')
    call require(all(current%occupied == expected%occupied), label // ' occupancy')
    call require(current%turn == expected%turn, label // ' side')
    call require(current%castling == expected%castling, label // ' castling')
    call require(current%ep == expected%ep, label // ' en passant')
    call require(current%halfmove == expected%halfmove, label // ' halfmove clock')
    call require(current%fullmove == expected%fullmove, label // ' fullmove number')
  end subroutine same_state

end program chess_core
