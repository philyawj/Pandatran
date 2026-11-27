program main
  use, intrinsic :: iso_fortran_env, only: error_unit, int64
  use pandatran, only: engine_name
  use chess_moves, only: max_moves, move_text
  use chess_positions, only: position, parse_fen, start_fen
  use chess_movegen, only: move_list
  use chess_perft, only: perft, perft_divide
  implicit none

  character(len=:), allocatable :: command, depth_text, fen
  type(position) :: pos
  type(move_list) :: list
  integer(int64) :: counts(max_moves), nodes
  integer :: depth, status, i

  select case (command_argument_count())
  case (0)
    print '(a)', engine_name
    stop
  case (2, 3)
    command = argument(1)
    depth_text = argument(2)
  case default
    call usage()
  end select
  if (command /= 'perft' .and. command /= 'divide') call usage()
  if (len(depth_text) == 0 .or. verify(depth_text, '0123456789') /= 0) call usage()
  read (depth_text, *, iostat=status) depth
  if (status /= 0) call usage()
  if (depth > 8 .or. (command == 'divide' .and. depth == 0)) call usage()

  fen = start_fen
  if (command_argument_count() == 3) fen = argument(3)
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

  subroutine usage()
    write (error_unit, '(a)') 'Usage: pandatran perft <0-8> ["FEN"] | pandatran divide <1-8> ["FEN"]'
    stop 2
  end subroutine usage

end program main
