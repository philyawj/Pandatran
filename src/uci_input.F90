module uci_input
  use, intrinsic :: iso_c_binding, only: c_char, c_int, c_intptr_t, c_long, c_short, c_size_t
  implicit none
  private

#if defined(PANDATRAN_MACOS)
  integer, parameter :: poll_count_kind = c_int
#elif defined(PANDATRAN_LINUX)
  integer, parameter :: poll_count_kind = c_long
#else
#error "The POSIX UCI transport supports macOS and Linux."
#endif

  integer, parameter, public :: line_ready = 1, no_line = 0, input_closed = -1

  type, bind(c) :: poll_descriptor
    integer(c_int) :: fd
    integer(c_short) :: events, revents
  end type poll_descriptor

  type, public :: line_reader
    integer(c_int) :: fd = 0
    character(kind=c_char, len=4096), private :: buffer
    character(len=:), allocatable, private :: partial
    integer, private :: first = 1, last = 0
    logical, private :: closed = .false.
  contains
    procedure :: read_line
  end type line_reader

  interface
    function poll(descriptor, count, timeout) bind(c, name='poll') result(ready)
      import :: poll_descriptor, poll_count_kind, c_int
      type(poll_descriptor), intent(inout) :: descriptor
      integer(poll_count_kind), value :: count
      integer(c_int), value :: timeout
      integer(c_int) :: ready
    end function poll

    function read_fd(fd, buffer, count) bind(c, name='read') result(size_read)
      import :: c_char, c_int, c_intptr_t, c_size_t
      integer(c_int), value :: fd
      character(kind=c_char), intent(out) :: buffer(*)
      integer(c_size_t), value :: count
      integer(c_intptr_t) :: size_read
    end function read_fd
  end interface

contains

  subroutine read_line(reader, timeout, line, status)
    class(line_reader), intent(inout) :: reader
    integer, intent(in) :: timeout
    character(len=:), allocatable, intent(out) :: line
    integer, intent(out) :: status
    type(poll_descriptor) :: descriptor
    integer(c_int) :: ready
    integer(c_intptr_t) :: size_read
    integer :: newline

    if (.not. allocated(reader%partial)) reader%partial = ''
    do
      if (reader%first <= reader%last) then
        newline = index(reader%buffer(reader%first:reader%last), achar(10))
        if (newline /= 0) then
          newline = reader%first + newline - 1
          line = reader%partial // reader%buffer(reader%first:newline-1)
          reader%partial = ''
          reader%first = newline + 1
          status = line_ready
          return
        end if
        reader%partial = reader%partial // reader%buffer(reader%first:reader%last)
        reader%first = reader%last + 1
      end if

      if (reader%closed) then
        status = input_closed
        return
      end if
      descriptor = poll_descriptor(reader%fd, 1_c_short, 0_c_short) ! POLLIN
      ready = poll(descriptor, int(1, poll_count_kind), int(timeout, c_int))
      if (ready == 0) then
        status = no_line
        return
      end if
      if (ready > 0) then
        size_read = read_fd(reader%fd, reader%buffer, len(reader%buffer, kind=c_size_t))
      else
        size_read = -1
      end if
      if (size_read <= 0) then
        reader%closed = .true.
        if (size_read == 0 .and. len(reader%partial) > 0) then
          call move_alloc(reader%partial, line)
          status = line_ready
          return
        end if
      end if
      reader%first = 1
      reader%last = int(size_read)
    end do
  end subroutine read_line

end module uci_input
