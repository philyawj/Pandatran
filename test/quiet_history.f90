program quiet_history
  use, intrinsic :: iso_fortran_env, only: error_unit, int64
  use chess_positions, only: position, parse_fen, start_fen, to_fen
  use chess_movegen, only: move_list, generate_legal
  use chess_draws, only: position_history, reset_history, history_key
  use chess_search, only: search_control, search_result, iterative_search, history_mode, lmr_mode
  implicit none

  type(position) :: pos
  type(position_history) :: history
  type(move_list) :: roots
  type(search_control) :: control
  type(search_result) :: trained, reference
  integer(int64) :: key, replay
  character(len=*), parameter :: ending = '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1'

  call load(start_fen)
  control%mode = history_mode
  control%node_limit = 4096
  call iterative_search(pos, history, roots, 6, control, trained)
  call check(control%nodes == control%node_limit .and. trained%depth > 0, 'interrupted search must keep a result')
  call check(any(control%quiet_history > 0), 'quiet cutoffs must earn bonuses')
  call check(any(control%quiet_history < 0), 'earlier quiet moves must receive penalties')
  call check(all(abs(control%quiet_history) <= 1024), 'history gravity must stay within bounds')
  call check(any(roots%moves(:roots%count) == trained%move), 'interrupted search produced an illegal move')
  call check(pos%key == key .and. history_key(history) == replay .and. to_fen(pos) == start_fen, &
    'interrupted quiet history search corrupted the position or replay')

  call iterative_search(pos, history, roots, 1, control, trained)
  call check(all(control%quiet_history == 0), 'history must reset before each new search')

  call load(ending)
  call control%table%clear()
  control%mode = lmr_mode
  control%node_limit = huge(0_int64)
  call iterative_search(pos, history, roots, 4, control, reference)
  call control%table%clear()
  control%mode = history_mode
  call iterative_search(pos, history, roots, 4, control, trained)
  call check(trained%depth == 4 .and. trained%score == reference%score, 'move ordering changed the exact endgame score')
  call check(control%reductions == 0, 'sparse ending must stay on the full-depth path')
  call check(pos%key == key .and. history_key(history) == replay .and. to_fen(pos) == ending, &
    'quiet history search corrupted the ending or its replay')

contains

  subroutine load(fen)
    character(len=*), intent(in) :: fen

    call check(parse_fen(fen, pos), 'invalid fixture')
    call generate_legal(pos, roots)
    call reset_history(pos, history)
    key = pos%key
    replay = history_key(history)
  end subroutine load

  subroutine check(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (condition) return
    write (error_unit, '(a)') message
    stop 1
  end subroutine check

end program quiet_history
