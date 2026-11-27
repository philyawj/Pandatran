program selective_search
  use, intrinsic :: iso_fortran_env, only: error_unit, int32, int64
  use chess_moves, only: parse_move
  use chess_positions, only: position, undo_state, make_move, parse_fen, start_fen, to_fen
  use chess_movegen, only: move_list, generate_legal
  use chess_draws, only: position_history, reset_history, history_key, record_game_position
  use chess_search, only: iterative_search, search_control, search_result, selective_node, &
    pvs_mode, lmr_mode, mate_score
  implicit none

  character(len=*), parameter :: checked = 'r3k2r/8/8/8/8/8/4R3/R3K3 b kq - 0 1'
  character(len=*), parameter :: quiet = 'r3k2r/8/8/8/8/8/5R2/R3K3 b kq - 0 1'
  character(len=*), parameter :: zugzwang = '8/8/8/4k3/8/4K3/4P3/8 w - - 0 1'
  character(len=*), parameter :: sparse = '4k3/8/8/8/8/8/4P3/1NN1K3 w - - 0 1'
  character(len=*), parameter :: mate = 'r6k/5Q2/6K1/8/8/4b3/8/R7 w - - 0 1'
  type(position) :: pos
  type(move_list) :: legal
  type(position_history) :: history
  type(search_control) :: control
  type(search_result) :: exact, trial

  call load(quiet)
  call check(selective_node(pos, history, 4, -1, 0), 'ordinary scout node should be eligible')
  call check(.not. selective_node(pos, history, 4, -30, 0), 'wide-window node must remain full search')
  call check(.not. selective_node(pos, history, 4, 29998, 29999), 'mate window must remain full search')
  call check(.not. selective_node(pos, history, 2, -1, 0), 'shallow node must remain full search')
  call load(checked)
  call check(.not. selective_node(pos, history, 4, -1, 0), 'checked side must keep its evasions')
  call load('r3k2r/8/8/8/8/8/5R2/R3K3 b kq - 99 50')
  call check(.not. selective_node(pos, history, 4, -1, 0), 'near a draw claim must remain full search')
  call load('r3k2r/8/8/8/8/8/5R2/R3K3 b - - 0 1')
  call advance('e8d8')
  call advance('e1d1')
  call advance('d8e8')
  call advance('d1e1')
  call check(.not. selective_node(pos, history, 4, -1, 0), 'a repeated position must remain full search')
  call load(zugzwang)
  call check(.not. selective_node(pos, history, 5, -1, 0), 'pawn ending must remain full search')
  call load(sparse)
  call check(.not. selective_node(pos, history, 5, -1, 0), 'sparse ending must remain full search')

  call exact_in_endgame(zugzwang)
  call exact_in_endgame(sparse)
  call load(mate)
  call search(pvs_mode, 5, exact)
  call search(lmr_mode, 5, trial)
  call check(exact%score == mate_score - 1 .and. trial%score == exact%score, 'mate in one must retain its distance')

  call load(start_fen)
  call search(lmr_mode, 6, trial)
  call check(control%reductions > 0 .and. control%reduced_researches > 0, 'LMR and full-depth retry must be exercised')
  call search(lmr_mode, 6, trial, limit=100000_int64)
  call check(control%nodes == 100000 .and. trial%depth > 0, 'node cap preserves a completed iteration')
  call check(control%reductions > 0, 'node cap exercised the selective search')

contains

  subroutine load(fen)
    character(len=*), intent(in) :: fen
    call check(parse_fen(fen, pos), 'invalid fixture: ' // fen)
    call reset_history(pos, history)
    call generate_legal(pos, legal)
  end subroutine load

  subroutine advance(text)
    character(len=*), intent(in) :: text
    type(undo_state) :: undo
    integer(int32) :: move

    call check(parse_move(text, move), 'invalid history move')
    call check(any(legal%moves(:legal%count) == move), 'illegal history move')
    call make_move(pos, move, undo)
    call record_game_position(pos, history)
    call generate_legal(pos, legal)
  end subroutine advance

  subroutine search(mode, depth, answer, limit)
    integer, intent(in) :: mode, depth
    type(search_result), intent(out) :: answer
    integer(int64), optional, intent(in) :: limit
    integer(int64) :: key, replay
    character(:), allocatable :: fen

    key = pos%key
    replay = history_key(history)
    fen = to_fen(pos)
    control%mode = mode
    control%node_limit = huge(0_int64)
    if (present(limit)) control%node_limit = limit
    call control%table%clear()
    call iterative_search(pos, history, legal, depth, control, answer)
    call check(pos%key == key .and. to_fen(pos) == fen .and. history_key(history) == replay, 'search corrupted state')
    call check(any(legal%moves(:legal%count) == answer%move), 'search returned an illegal move')
  end subroutine search

  subroutine exact_in_endgame(fen)
    character(len=*), intent(in) :: fen
    call load(fen)
    call search(pvs_mode, 5, exact)
    call search(lmr_mode, 5, trial)
    call check(trial%score == exact%score .and. trial%depth == exact%depth, 'sparse control changed: ' // fen)
    call check(control%reductions == 0, 'sparse control was pruned: ' // fen)
  end subroutine exact_in_endgame

  subroutine check(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (condition) return
    write (error_unit, '(a)') message
    stop 1
  end subroutine check

end program selective_search
