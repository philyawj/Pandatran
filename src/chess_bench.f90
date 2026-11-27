module chess_bench
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use chess_moves, only: move_text
  use chess_positions, only: position, parse_fen, start_fen
  use chess_movegen, only: generate_legal, move_list
  use chess_evaluation, only: evaluate
  use chess_draws, only: position_history, reset_history
  use chess_search, only: iterative_search, search_control, search_result, &
    plain_mode, order_mode, table_mode, pvs_mode, aspiration_mode, default_mode, lmr_mode, history_mode
  implicit none
  private
  public :: run_bench, bench_mode, run_eval_bench

  type :: bench_case
    character(len=16) :: name
    character(len=96) :: fen
  end type bench_case

  type(bench_case), parameter :: suite(*) = [ &
    bench_case('start', start_fen), &
    bench_case('kiwipete', 'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1'), &
    bench_case('rook-endgame', '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1'), &
    bench_case('recapture', '4kr2/8/5p2/8/8/8/5Q2/4K3 w - - 0 1'), &
    bench_case('quiet-evasion', '7k/8/6p1/8/8/8/8/KR6 w - - 0 1'), &
    bench_case('mate-in-one', '7k/5Q2/6K1/8/8/8/8/8 w - - 0 1'), &
    bench_case('dead-bishops', '4k3/8/8/4b3/8/8/8/2B1K3 w - - 0 1') ]

contains

  integer function bench_mode(name) result(mode)
    character(len=*), intent(in) :: name

    select case (name)
    case ('default')
      mode = default_mode
    case ('plain')
      mode = plain_mode
    case ('order')
      mode = order_mode
    case ('table')
      mode = table_mode
    case ('pvs')
      mode = pvs_mode
    case ('aspiration')
      mode = aspiration_mode
    case ('lmr')
      mode = lmr_mode
    case ('history')
      mode = history_mode
    case default
      mode = -1
    end select
  end function bench_mode

  subroutine run_bench(depth, node_limit, mode, profile)
    integer, intent(in) :: depth, mode, profile
    integer(int64), intent(in) :: node_limit
    type(position) :: pos
    type(position_history) :: history
    type(search_control) :: control
    type(search_result) :: result
    type(move_list) :: roots
    character(len=5) :: move
    integer :: i

    control%node_limit = node_limit
    control%mode = mode
    control%evaluation = profile
    do i = 1, size(suite)
      call control%table%clear()
      if (.not. parse_fen(suite(i)%fen, pos)) error stop 'Invalid bench FEN: ' // trim(suite(i)%name)
      call reset_history(pos, history)
      call generate_legal(pos, roots)
      call iterative_search(pos, history, roots, depth, control, result)
      move = '0000'
      if (result%move /= 0) move = move_text(result%move)
      write (*, '(3a,a,a,i0,a,i0,a,i0)', advance='no') 'case=', trim(suite(i)%name), ' move=', trim(move), &
        ' score=', result%score, ' depth=', result%depth, ' nodes=', control%nodes
      select case (mode)
      case (lmr_mode, history_mode)
        write (*, '(a,i0,a,i0)') ' reductions=', control%reductions, ' retries=', control%reduced_researches
      case default
        write (*, '(a)') ''
      end select
    end do
  end subroutine run_bench

  subroutine run_eval_bench(profile)
    integer, intent(in) :: profile
    integer, parameter :: repetitions = 100000
    type(position) :: positions(size(suite))
    integer(int64) :: ticks, start, finish, checksum
    integer :: i, iteration
    real(real64) :: nanoseconds

    do i = 1, size(suite)
      if (.not. parse_fen(suite(i)%fen, positions(i))) error stop 'Invalid bench FEN: ' // trim(suite(i)%name)
    end do
    checksum = 0
    call system_clock(start, ticks)
    do iteration = 1, repetitions
      do i = 1, size(suite)
        checksum = checksum + evaluate(positions(i), profile)
      end do
    end do
    call system_clock(finish)
    nanoseconds = 1.0e9_real64 * real(finish - start, real64) / real(ticks, real64)
    write (*, '(a,i0,a,f8.1,a,i0)') 'evaluations=', repetitions * size(suite), &
      ' ns_per_eval=', nanoseconds / (repetitions * size(suite)), ' checksum=', checksum
  end subroutine run_eval_bench

end module chess_bench
