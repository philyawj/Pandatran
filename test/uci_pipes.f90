program uci_pipes
  use, intrinsic :: iso_c_binding, only: c_char, c_int, c_intptr_t, c_size_t, c_null_char, c_ptr, c_loc, c_null_ptr
  use, intrinsic :: iso_fortran_env, only: error_unit
  use uci_input, only: line_reader, line_ready, no_line, input_closed
  implicit none

  interface
    function pipe(fds) bind(c) result(status)
      import :: c_int
      integer(c_int), intent(out) :: fds(2)
      integer(c_int) :: status
    end function pipe

    function fork() bind(c) result(pid)
      import :: c_int
      integer(c_int) :: pid
    end function fork

    function dup2(oldfd, newfd) bind(c) result(fd)
      import :: c_int
      integer(c_int), value :: oldfd, newfd
      integer(c_int) :: fd
    end function dup2

    function close_fd(fd) bind(c, name='close') result(status)
      import :: c_int
      integer(c_int), value :: fd
      integer(c_int) :: status
    end function close_fd

    function execv(path, argv) bind(c) result(status)
      import :: c_char, c_ptr, c_int
      character(kind=c_char), intent(in) :: path(*)
      type(c_ptr), intent(in) :: argv(*)
      integer(c_int) :: status
    end function execv

    subroutine child_exit(code) bind(c, name='_exit')
      import :: c_int
      integer(c_int), value :: code
    end subroutine child_exit

    function write_fd(fd, bytes, count) bind(c, name='write') result(written)
      import :: c_char, c_int, c_size_t, c_intptr_t
      integer(c_int), value :: fd
      character(kind=c_char), intent(in) :: bytes(*)
      integer(c_size_t), value :: count
      integer(c_intptr_t) :: written
    end function write_fd

    function waitpid(pid, status, options) bind(c) result(child)
      import :: c_int
      integer(c_int), value :: pid, options
      integer(c_int), intent(out) :: status
      integer(c_int) :: child
    end function waitpid

    function kill(pid, signal) bind(c) result(status)
      import :: c_int
      integer(c_int), value :: pid, signal
      integer(c_int) :: status
    end function kill
  end interface

  character(len=1), parameter :: lf = achar(10), cr = achar(13)
  character(len=*), parameter :: mate = '7k/6Q1/5K2/8/8/8/8/8 b - - 0 1'
  character(kind=c_char, len=:), allocatable, target :: executable
  character(len=:), allocatable :: actual, arg0
  type(line_reader) :: first_engine, second_engine
  integer(c_int) :: pid = -1, engine_stdin
  integer :: length, slash

  ! fpm places the test and engine in sibling test/ and app/ directories.
  call get_command_argument(0, length=length)
  allocate(character(len=length) :: arg0)
  call get_command_argument(0, value=arg0)
  slash = scan(arg0, '/', back=.true.)
  call check(slash > 0, 'expected an fpm test executable path')
  slash = scan(arg0(:slash-1), '/', back=.true.)
  call check(slash > 0, 'expected a directory containing the fpm test executable')
  executable = arg0(:slash) // 'app/pandatran' // c_null_char

  call start(first_engine)
  call send('uci' // lf // 'isready' // lf)
  call expect(first_engine, 'id name Pandatran')
  call expect(first_engine, 'id author philyawj')
  call expect(first_engine, 'uciok')
  call expect(first_engine, 'readyok')

  call send('isrea')
  call quiet(first_engine)
  call send('dy' // cr // lf)
  call expect(first_engine, 'readyok')
  call send(repeat(' ', 5000) // 'isready' // lf)
  call expect(first_engine, 'readyok')

  call send('position startpos' // lf // 'go nodes 21' // lf)
  call expect(first_engine, 'info depth 1 nodes 20 ', prefix=.true.)
  call expect(first_engine, 'bestmove b1c3')

  call send('position startpos moves e2e4 c7c5 g1f3' // lf // 'go depth 1 searchmoves d7d5' // lf)
  call expect(first_engine, 'info depth 1', prefix=.true.)
  call expect(first_engine, 'bestmove d7d5')
  call send('position startpos moves e2e5' // lf // 'go movetime 0 searchmoves b8c6' // lf)
  call expect(first_engine, 'info string invalid position')
  call expect(first_engine, 'bestmove b8c6')
  call send('go searchmoves d7d5 nodes 1' // lf)
  call expect(first_engine, 'info depth 1 nodes 1 ', prefix=.true.)
  call expect(first_engine, 'bestmove d7d5')
  call send('position fen 7k/5Q2/6K1/8/8/8/8/8 w - - 0 1' // lf // 'go depth 1 searchmoves f7g7' // lf)
  call expect(first_engine, 'info depth 1 nodes 1 score mate 1 pv f7g7')
  call expect(first_engine, 'bestmove f7g7')
  call send('position fen rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1 moves c7c5 g1f3' // lf)

  call send('go infinite depth 1 searchmoves d7d5' // lf)
  call expect(first_engine, 'info depth 1', prefix=.true.)
  call send('isready' // lf)
  call expect(first_engine, 'readyok')
  call quiet(first_engine)
  call send('stop' // lf)
  call expect(first_engine, 'bestmove d7d5')

  call send('go infinite searchmoves b8c6' // lf // 'stop' // lf)
  call expect(first_engine, 'bestmove b8c6')
  call quiet(first_engine)

  call send('go infinite searchmoves b8c6' // lf)
  call expect(first_engine, 'info depth 1', prefix=.true.)
  call send('go depth 1 searchmoves d7d5' // lf)
  call expect(first_engine, 'bestmove d7d5', skip_info=.true.)
  call quiet(first_engine)

  call send('go infinite searchmoves b8c6' // lf)
  call expect(first_engine, 'info depth 1', prefix=.true.)
  call send('isready' // lf)
  call expect(first_engine, 'readyok', skip_info=.true.)
  call send('position fen ' // mate // lf // 'go depth 1' // lf)
  call expect(first_engine, 'bestmove 0000', skip_info=.true.)
  call quiet(first_engine)

  call send('position startpos' // lf // 'go infinite' // lf)
  call expect(first_engine, 'info depth 1', prefix=.true.)
  call send('quit' // lf)
  call finished(first_engine)

  call start(second_engine)
  call send('position startpos' // lf // 'go infinite' // lf)
  call expect(second_engine, 'info depth 1', prefix=.true.)
  call check(close_fd(engine_stdin) == 0, 'close engine stdin')
  engine_stdin = -1
  call finished(second_engine)

contains

  subroutine start(reader)
    type(line_reader), intent(inout) :: reader
    integer(c_int) :: to_engine(2), from_engine(2), unused
    type(c_ptr) :: argv(2)

    call check(pipe(to_engine) == 0, 'cannot create engine input pipe')
    call check(pipe(from_engine) == 0, 'cannot create engine output pipe')
    pid = fork()
    call check(pid >= 0, 'cannot start engine process')
    if (pid == 0) then
      if (dup2(to_engine(1), 0_c_int) /= 0) call child_exit(126_c_int)
      if (dup2(from_engine(2), 1_c_int) /= 1) call child_exit(126_c_int)
      unused = close_fd(to_engine(1))
      unused = close_fd(to_engine(2))
      unused = close_fd(from_engine(1))
      unused = close_fd(from_engine(2))
      argv = [c_loc(executable(1:1)), c_null_ptr]
      unused = execv(executable, argv)
      call child_exit(127_c_int)
    end if
    call check(close_fd(to_engine(1)) == 0, 'close parent input reader')
    call check(close_fd(from_engine(2)) == 0, 'close parent output writer')
    engine_stdin = to_engine(2)
    reader%fd = from_engine(1)
  end subroutine start

  subroutine send(text)
    character(len=*), intent(in) :: text
    integer(c_intptr_t) :: written
    integer :: first

    first = 1
    do while (first <= len(text))
      written = write_fd(engine_stdin, text(first:), int(len(text) - first + 1, c_size_t))
      call check(written > 0, 'cannot send to engine: ' // text)
      first = first + int(written)
    end do
  end subroutine send

  subroutine expect(reader, expected, prefix, skip_info)
    type(line_reader), intent(inout) :: reader
    character(len=*), intent(in) :: expected
    logical, intent(in), optional :: prefix, skip_info
    integer :: status

    do
      call reader%read_line(2000, actual, status)
      call check(status == line_ready, 'timed out or closed waiting for ' // expected)
      if (.not. present(skip_info)) exit
      if (.not. skip_info .or. index(actual, 'info depth ') /= 1) exit
    end do
    if (present(prefix)) then
      if (prefix) then
        call check(index(actual, expected) == 1, 'expected prefix ' // expected // ', got ' // actual)
        return
      end if
    end if
    call check(actual == expected, 'expected ' // expected // ', got ' // actual)
  end subroutine expect

  subroutine quiet(reader)
    type(line_reader), intent(inout) :: reader
    integer :: status

    call reader%read_line(30, actual, status)
    call check(status == no_line, 'expected no protocol output')
  end subroutine quiet

  subroutine finished(reader)
    type(line_reader), intent(inout) :: reader
    integer :: status
    integer(c_int) :: waited, exit_status

    do
      call reader%read_line(2000, actual, status)
      if (status == input_closed) exit
      call check(status == line_ready, 'engine did not exit')
      call check(index(actual, 'info depth ') == 1, 'unexpected output before exit: ' // actual)
    end do
    if (engine_stdin >= 0) call check(close_fd(engine_stdin) == 0, 'close parent writer')
    call check(close_fd(reader%fd) == 0, 'close parent reader')
    waited = waitpid(pid, exit_status, 0_c_int)
    call check(waited == pid, 'cannot reap engine process')
    pid = -1
    call check(exit_status == 0, 'engine exited unsuccessfully')
  end subroutine finished

  subroutine check(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    integer(c_int) :: unused, exit_status

    if (condition) return
    write (error_unit, '(a)') message
    if (pid > 0) then
      unused = kill(pid, 9_c_int)
      unused = waitpid(pid, exit_status, 0_c_int)
    end if
    stop 1
  end subroutine check

end program uci_pipes
