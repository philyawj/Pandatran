module uci_clock
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  private

  type, public :: search_budget
    real(real64) :: soft = -1.0_real64, hard = -1.0_real64
  end type search_budget

  public :: budget_for_move, stop_after_iteration

contains

  pure function budget_for_move(remaining_ms, increment_ms, moves_to_go, movetime_ms, infinite) result(budget)
    integer(int64), intent(in) :: remaining_ms, increment_ms, moves_to_go, movetime_ms
    logical, intent(in) :: infinite
    type(search_budget) :: budget
    real(real64) :: remaining, reserve, available

    budget = search_budget()
    if (infinite) return
    if (movetime_ms >= 0) budget%hard = 0.001_real64 * real(movetime_ms, real64)
    if (remaining_ms < 0) return
    remaining = 0.001_real64 * real(remaining_ms, real64)
    reserve = min(0.025_real64, max(0.001_real64, 0.10_real64 * remaining))
    available = max(0.0_real64, remaining - reserve)
    if (movetime_ms >= 0) then
      budget%hard = min(available, budget%hard)
    else
      budget%soft = min(available, available / real(moves_to_go, real64) + 0.00065_real64 * real(increment_ms, real64))
      budget%hard = min(available, 1.5_real64 * budget%soft)
    end if
  end function budget_for_move

  pure logical function stop_after_iteration(soft, elapsed, duration, nodes, previous_nodes, stable) result(stopped)
    real(real64), intent(in) :: soft, elapsed, duration
    integer(int64), intent(in) :: nodes, previous_nodes
    logical, intent(in) :: stable
    real(real64) :: growth

    stopped = .false.
    if (soft < 0.0_real64 .or. .not. stable .or. previous_nodes <= 0) return
    growth = min(4.0_real64, max(3.0_real64, real(nodes, real64) / real(previous_nodes, real64)))
    stopped = elapsed + growth * duration >= soft
  end function stop_after_iteration

end module uci_clock
