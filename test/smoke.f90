program smoke
  use, intrinsic :: iso_fortran_env, only: int64
  use pandatran, only: engine_name
  implicit none

  if (engine_name /= 'Pandatran') error stop 'Unexpected engine name'
  if (bit_size(0_int64) /= 64) error stop 'Chess bitboards require 64-bit integers'
end program smoke
