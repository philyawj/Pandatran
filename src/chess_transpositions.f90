module chess_transpositions
  use, intrinsic :: iso_fortran_env, only: int16, int32, int64
  implicit none
  private

  integer, parameter :: capacity = 65536, mate_floor = 29000
  integer(int16), parameter, public :: exact_bound = 1, lower_bound = 2, upper_bound = 3

  type :: table_entry
    integer(int64) :: key = 0, history = 0
    integer(int32) :: move = 0
    integer(int16) :: score = 0, halfmove = 0, depth = 0, bound = 0
  end type table_entry

  integer, parameter, public :: table_bytes = capacity * storage_size(table_entry()) / 8

  type, public :: transposition_table
    private
    type(table_entry), allocatable :: entries(:)
  contains
    procedure :: prepare
    procedure :: clear
    procedure :: probe
    procedure :: store
  end type transposition_table

contains

  subroutine prepare(table)
    class(transposition_table), intent(inout) :: table

    if (.not. allocated(table%entries)) allocate(table%entries(capacity))
  end subroutine prepare

  subroutine clear(table)
    class(transposition_table), intent(inout) :: table

    if (allocated(table%entries)) table%entries = table_entry()
  end subroutine clear

  subroutine probe(table, key, history, halfmove, depth, ply, alpha, beta, hit, score, move)
    class(transposition_table), intent(in) :: table
    integer(int64), intent(in) :: key, history, halfmove
    integer, intent(in) :: depth, ply, alpha, beta
    logical, intent(out) :: hit
    integer, intent(out) :: score
    integer(int32), intent(out) :: move
    integer :: index

    hit = .false.
    score = 0
    move = 0
    if (.not. allocated(table%entries)) return
    index = slot(key)
    associate (entry => table%entries(index))
      if (entry%bound == 0 .or. entry%key /= key) return
      move = entry%move
      if (entry%history /= history .or. entry%halfmove /= halfmove .or. entry%depth /= depth) return
      score = int(entry%score)
      if (abs(score) >= mate_floor) score = score - sign(ply, score)
      select case (entry%bound)
      case (exact_bound)
        hit = .true.
      case (lower_bound)
        hit = score >= beta
      case (upper_bound)
        hit = score <= alpha
      end select
    end associate
  end subroutine probe

  subroutine store(table, key, history, halfmove, depth, ply, score, bound, move)
    class(transposition_table), intent(inout) :: table
    integer(int64), intent(in) :: key, history, halfmove
    integer, intent(in) :: depth, ply, score
    integer(int16), intent(in) :: bound
    integer(int32), intent(in) :: move
    integer :: adjusted, index

    adjusted = score
    if (abs(adjusted) >= mate_floor) adjusted = adjusted + sign(ply, adjusted)
    index = slot(key)
    associate (entry => table%entries(index))
      if (entry%bound /= 0 .and. entry%key == key .and. entry%history == history .and. entry%halfmove == halfmove) then
        if (entry%depth > depth) return
        if (entry%depth == depth .and. entry%bound == exact_bound .and. bound /= exact_bound) return
      end if
      entry = table_entry(key, history, move, int(adjusted, int16), int(halfmove, int16), int(depth, int16), bound)
    end associate
  end subroutine store

  pure integer function slot(key) result(index)
    integer(int64), intent(in) :: key

    index = int(iand(key, int(capacity - 1, int64))) + 1
  end function slot

end module chess_transpositions
