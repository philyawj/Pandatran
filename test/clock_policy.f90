program clock_policy
  use, intrinsic :: iso_fortran_env, only: error_unit, int64, real64
  use uci_clock, only: search_budget, budget_for_move, stop_after_iteration
  implicit none

  type(search_budget) :: budget

  budget = budget_for_move(-1_int64, 0_int64, 24_int64, -1_int64, .false.)
  call check(budget%soft < 0 .and. budget%hard < 0, 'untimed depth and node searches have no clock deadline')
  budget = budget_for_move(5000_int64, 500_int64, 24_int64, 80_int64, .true.)
  call check(budget%soft < 0 .and. budget%hard < 0, 'infinite search must wait for a command')
  budget = budget_for_move(37_int64, 0_int64, 24_int64, 80_int64, .false.)
  call check(budget%soft < 0 .and. near(budget%hard, 0.0333_real64), 'movetime must respect the available clock')
  budget = budget_for_move(-1_int64, 0_int64, 24_int64, 80_int64, .false.)
  call check(budget%soft < 0 .and. near(budget%hard, 0.080_real64), 'movetime alone must remain a hard limit')
  budget = budget_for_move(1_int64, 6000_int64, 24_int64, -1_int64, .false.)
  call check(near(budget%hard, 0.0_real64), 'future increment cannot fund an expired clock')
  budget = budget_for_move(5_int64, 6000_int64, 24_int64, -1_int64, .false.)
  call check(near(budget%hard, 0.004_real64), 'near-empty clocks must keep the reserve')
  budget = budget_for_move(5000_int64, 500_int64, 10_int64, -1_int64, .false.)
  call check(near(budget%soft, 0.8225_real64), 'soft limit must include moves to go and increment')
  call check(near(budget%hard, 1.23375_real64), 'hard limit must allow a bounded extension')
  call check(stop_after_iteration(0.2_real64, 0.11_real64, 0.04_real64, 300_int64, 100_int64, .true.), &
    'stable best move should preserve time when the next depth is unlikely to finish')
  call check(.not. stop_after_iteration(0.2_real64, 0.11_real64, 0.04_real64, 300_int64, 100_int64, .false.), &
    'a newly changed move should get another iteration if the hard deadline allows')
  call check(.not. stop_after_iteration(0.2_real64, 0.06_real64, 0.03_real64, 300_int64, 100_int64, .true.), &
    'stable best move should still search a depth that fits')

contains

  logical function near(actual, expected)
    real(real64), intent(in) :: actual, expected
    near = abs(actual - expected) < 1.0e-9_real64
  end function near

  subroutine check(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (condition) return
    write (error_unit, '(a)') message
    stop 1
  end subroutine check

end program clock_policy
