program main
  use, intrinsic :: iso_fortran_env, only: error_unit, int64
  use uci_session, only: run_uci
  use chess_moves, only: max_moves, move_text
  use chess_positions, only: position, parse_fen, start_fen
  use chess_movegen, only: move_list
  use chess_perft, only: perft, perft_divide
  use chess_bench, only: run_bench, bench_mode
  implicit none

  character(len=:), allocatable :: command, depth_text, fen
  type(position) :: pos
  type(move_list) :: list
  integer(int64) :: counts(max_moves), nodes, node_limit
  integer :: depth, status, i, argc, mode

  argc = command_argument_count()
  if (argc == 0) then
    call run_uci()
    stop
  end if
  command = argument(1)
  if (command == 'bench') then
    if (argc > 4) call usage()
    depth = 3
    node_limit = huge(node_limit)
    mode = bench_mode('default')
    if (argc >= 2) then
      nodes = positive_argument(2)
      if (nodes > 8) call usage()
      depth = int(nodes)
    end if
    if (argc == 3) then
      mode = bench_mode(argument(3))
      if (mode < 0) then
        node_limit = positive_argument(3)
        mode = bench_mode('default')
      end if
    else if (argc == 4) then
      node_limit = positive_argument(3)
      mode = bench_mode(argument(4))
      if (mode < 0) call usage()
    end if
    call run_bench(depth, node_limit, mode)
    stop
  end if
  if (argc < 2 .or. argc > 3) call usage()
  depth_text = argument(2)
  if (command /= 'perft' .and. command /= 'divide') call usage()
  if (len(depth_text) == 0 .or. verify(depth_text, '0123456789') /= 0) call usage()
  read (depth_text, *, iostat=status) depth
  if (status /= 0) call usage()
  if (depth > 8 .or. (command == 'divide' .and. depth == 0)) call usage()

  fen = start_fen
  if (argc == 3) fen = argument(3)
  if (.not. parse_fen(fen, pos)) then
    write (error_unit, '(a)') 'Invalid six-field FEN'
    stop 2
  end if
  if (command == 'perft') then
    nodes = perft(pos, depth)
  else
    call perft_divide(pos, depth, list, counts)
    do i = 1, list%count
      print '(a,": ",i0)', trim(move_text(list%moves(i))), counts(i)
    end do
    nodes = sum(counts(:list%count))
  end if
  print '("Nodes searched: ",i0)', nodes

contains

  function argument(index) result(value)
    integer, intent(in) :: index
    character(len=:), allocatable :: value
    integer :: length

    call get_command_argument(index, length=length)
    allocate(character(len=length) :: value)
    call get_command_argument(index, value=value)
  end function argument

  integer(int64) function positive_argument(index) result(value)
    integer, intent(in) :: index
    character(len=:), allocatable :: text
    integer :: parse_status

    text = argument(index)
    if (len(text) == 0 .or. verify(text, '0123456789') /= 0) call usage()
    read (text, *, iostat=parse_status) value
    if (parse_status /= 0) call usage()
    if (value <= 0) call usage()
  end function positive_argument

  subroutine usage()
    write (error_unit, '(a)') 'Usage: pandatran | pandatran perft <0-8> ["FEN"] | pandatran divide <1-8> ["FEN"]'
    write (error_unit, '(a)') '       pandatran bench [depth 1-8 [nodes per position] [mode]]'
    write (error_unit, '(a)') '       modes: default, plain, order, table, pvs, aspiration'
    stop 2
  end subroutine usage

end program main
