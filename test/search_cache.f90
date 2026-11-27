program search_cache
  use, intrinsic :: iso_fortran_env, only: error_unit, int32, int64
  use chess_positions, only: position, undo_state, parse_fen, make_move, to_fen, recompute_key, start_fen
  use chess_moves, only: parse_move
  use chess_movegen, only: generate_legal, move_list
  use chess_draws, only: position_history, reset_history, record_game_position, history_key, repetitions
  use chess_search, only: search_control, search_result, iterative_search, plain_mode, table_mode, aspiration_mode, &
    mate_score, mate_threshold
  use chess_transpositions
  implicit none

  integer(int64), parameter :: key = 12345, context = 23, clock = 16, colliding_key = key + 65536
  integer(int32), parameter :: hint = 786
  character(len=*), parameter :: endgame = 'r3k3/8/8/8/8/8/8/4K3 b - - 0 1'
  type(transposition_table) :: table
  type(position) :: pos, contextual_pos
  type(position_history) :: history, fresh_history
  type(search_control) :: control
  type(search_result) :: result, reference
  type(move_list) :: roots
  integer(int32) :: move
  integer :: i, mode
  integer(int64) :: contextual_key, board_key, cold_nodes

  call check(table_bytes <= 3 * 1024 * 1024, 'table exceeds the match cache budget')
  call expect_probe(key, context, clock, 4, 0, -70, 70, .false., 0, 0_int32)
  call table%prepare()
  call table%store(key, context, clock, 4, 0, 24, exact_bound, hint)
  call expect_probe(key, context, clock, 4, 0, 40, 60, .true., 24, hint)
  call expect_probe(key, context + 1, clock, 4, 0, -70, 70, .false., 0, hint)
  call expect_probe(key, context, clock + 1, 4, 0, -70, 70, .false., 0, hint)
  call expect_probe(key, context, clock, 3, 0, -70, 70, .false., 0, hint)
  call expect_probe(colliding_key, context, clock, 4, 0, -70, 70, .false., 0, 0_int32)
  call table%store(key, context, clock, 3, 0, 20, lower_bound, hint)
  call expect_probe(key, context, clock, 4, 0, -70, 70, .true., 24, hint)
  call table%store(key, context, clock, 4, 0, 20, lower_bound, hint)
  call expect_probe(key, context, clock, 4, 0, -70, 70, .true., 24, hint)

  call table%store(colliding_key, context, clock, 4, 0, 96, lower_bound, hint)
  call expect_probe(key, context, clock, 4, 0, -70, 70, .false., 0, 0_int32)
  call expect_probe(colliding_key, context, clock, 4, 0, -80, 96, .true., 96, hint)
  call expect_probe(colliding_key, context, clock, 4, 0, -80, 97, .false., 96, hint)
  call table%store(key, context, clock, 4, 0, -96, upper_bound, hint)
  call expect_probe(key, context, clock, 4, 0, -96, 40, .true., -96, hint)
  call expect_probe(key, context, clock, 4, 0, -97, 40, .false., -96, hint)
  call table%store(key, context, clock, 4, 4, 29995, exact_bound, hint)
  call expect_probe(key, context, clock, 4, 7, -32000, 32000, .true., 29992, hint)
  call table%store(key, context, clock, 4, 4, -29995, exact_bound, hint)
  call expect_probe(key, context, clock, 4, 7, -32000, 32000, .true., -29992, hint)
  call table%clear()
  call expect_probe(key, context, clock, 4, 7, -32000, 32000, .false., 0, 0_int32)

  call load('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1')
  board_key = pos%key
  call load('r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1')
  call check(pos%key /= board_key, 'the key must distinguish sides')
  call load('r3k2r/8/8/8/8/8/8/R3K2R w Qkq - 0 1')
  call check(pos%key /= board_key, 'the key must distinguish castling rights')
  call load('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 99 50')
  call check(pos%key == board_key, 'halfmove clocks belong to score lookup')
  call load('4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2')
  board_key = pos%key
  call load('4k3/8/8/3pP3/8/8/8/4K3 w - - 0 2')
  call check(pos%key /= board_key, 'the key must distinguish en passant targets')

  call load(start_fen)
  call advance('e2e4')
  call reset_history(pos, fresh_history)
  call check(history_key(history) == history_key(fresh_history), 'a pawn move resets the prior context')
  call load('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1')
  call advance('h1h2')
  call reset_history(pos, fresh_history)
  call check(history_key(history) == history_key(fresh_history), 'losing castling rights resets the prior context')

  call load(endgame)
  do i = 1, 2
    call advance('e8f8')
    call advance('e1f1')
    call advance('f8e8')
    call advance('f1e1')
  end do
  call check(repetitions(history) == 3, 'tracked rehearsal has three occurrences')
  contextual_pos = pos
  contextual_key = history_key(history)
  call check(parse_fen(to_fen(pos), contextual_pos), 'same FEN without the replay')
  call reset_history(contextual_pos, fresh_history)
  call check(contextual_pos%key == pos%key .and. contextual_pos%halfmove == pos%halfmove, 'same board and clock')
  call check(contextual_key /= history_key(fresh_history), 'the score key must distinguish history')

  call check(parse_move('e8f8', move), 'valid root restriction')
  roots%count = 1
  roots%moves(1) = move
  control%mode = table_mode
  call iterative_search(pos, history, roots, 2, control, result)
  call check(result%score == 0, 'warm the table with a draw-aware score')
  call check(history_key(history) == contextual_key, 'search restored the history fingerprint')
  call iterative_search(contextual_pos, fresh_history, roots, 2, control, result)
  call check(result%score > 400, 'the cached draw must not contaminate the same FEN')
  control%mode = plain_mode
  call iterative_search(contextual_pos, fresh_history, roots, 2, control, reference)
  call check(result%score == reference%score, 'cache agrees with uncached search')

  call control%table%clear()
  control%mode = table_mode
  call load(endgame)
  call generate_legal(pos, roots)
  call iterative_search(pos, history, roots, 3, control, reference)
  cold_nodes = control%nodes
  call iterative_search(pos, history, roots, 3, control, result)
  call check(result%depth == reference%depth .and. result%score == reference%score, 'warm cache changed the result')
  call check(control%nodes < cold_nodes, 'warm cache did not save any nodes')

  control%mode = plain_mode
  call load('4kr2/8/5p2/8/8/8/5Q2/4K3 w - - 0 1')
  call generate_legal(pos, roots)
  call iterative_search(pos, history, roots, 3, control, reference)
  do mode = plain_mode + 1, aspiration_mode
    call control%table%clear()
    control%mode = mode
    call iterative_search(pos, history, roots, 3, control, result)
    call check(result%depth == reference%depth .and. result%score == reference%score, 'mode changed a fixed-depth score')
    call check(any(roots%moves(:roots%count) == result%move), 'mode returned an illegal root move')
  end do

  call load('8/8/8/5Q2/8/5K2/8/6k1 w - - 0 1')
  call generate_legal(pos, roots)
  control%mode = plain_mode
  call iterative_search(pos, history, roots, 1, control, reference)
  call check(abs(reference%score) < mate_threshold, 'the shallow aspiration center should be finite')
  call control%table%clear()
  control%mode = aspiration_mode
  call iterative_search(pos, history, roots, 3, control, result)
  call check(result%score == mate_score - 3, 'failed aspiration must recover the full-window mate distance')

contains

  subroutine load(fen)
    character(len=*), intent(in) :: fen

    call check(parse_fen(fen, pos), 'invalid fixture: ' // fen)
    call check(recompute_key(pos) == pos%key, 'recomputed fixture key')
    call reset_history(pos, history)
  end subroutine load

  subroutine advance(text)
    character(len=*), intent(in) :: text
    type(undo_state) :: undo

    call check(parse_move(text, move), 'valid history fixture')
    call generate_legal(pos, roots)
    call check(any(roots%moves(:roots%count) == move), 'legal history fixture')
    call make_move(pos, move, undo)
    call record_game_position(pos, history)
  end subroutine advance

  subroutine expect_probe(board, replay, halfmove, depth, ply, alpha, beta, expected_hit, expected_score, expected_move)
    integer(int64), intent(in) :: board, replay, halfmove
    integer, intent(in) :: depth, ply, alpha, beta, expected_score
    logical, intent(in) :: expected_hit
    integer(int32), intent(in) :: expected_move
    integer :: score
    integer(int32) :: best_move
    logical :: hit

    call table%probe(board, replay, halfmove, depth, ply, alpha, beta, hit, score, best_move)
    call check(hit .eqv. expected_hit, 'incorrect cache hit')
    call check(score == expected_score, 'incorrect cache score')
    call check(best_move == expected_move, 'incorrect cache move hint')
  end subroutine expect_probe

  subroutine check(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (condition) return
    write (error_unit, '(a)') message
    stop 1
  end subroutine check

end program search_cache
