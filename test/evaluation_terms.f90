program evaluation_terms
  use, intrinsic :: iso_fortran_env, only: error_unit
  use chess_moves, only: white, black
  use chess_positions, only: position, parse_fen, start_fen
  use chess_evaluation, only: evaluate, evaluation_profile, game_phase, tapered_eval, &
    pawns_eval, mobility_eval, safety_eval
  implicit none

  character(len=*), parameter :: passed = '4k3/p7/8/4P3/8/8/8/4K3 w - - 0 1'
  character(len=*), parameter :: contested = '4k3/3p4/8/4P3/8/8/8/4K3 w - - 0 1'
  character(len=*), parameter :: blocked = '8/8/4k3/4P3/8/8/8/4K3 w - - 0 1'
  character(len=*), parameter :: unblocked = '8/8/6k1/4P3/8/8/8/4K3 w - - 0 1'
  character(len=*), parameter :: doubled = '4k3/8/8/8/4P3/4P3/8/4K3 w - - 0 1'
  character(len=*), parameter :: connected = '4k3/8/8/8/5P2/4P3/8/4K3 w - - 0 1'
  character(len=*), parameter :: sheltered = 'q3k2r/7p/8/8/8/8/5PPP/6K1 w - - 0 1'
  character(len=*), parameter :: exposed = 'q3k2r/7p/8/8/6P1/8/5P1P/6K1 w - - 0 1'
  character(len=*), parameter :: terms = 'q3k2r/7p/2p5/4P3/4N3/8/5PPP/6K1 w - - 0 1'
  character(len=*), parameter :: reflected = '6k1/5ppp/8/4n3/4p3/2P5/7P/Q3K2R b - - 0 1'
  type(position) :: pos, mirror
  integer :: profile, score

  call check(parse_fen(start_fen, pos), 'start position is invalid')
  call check(game_phase(pos) == 24, 'the start position must have full middlegame weight')
  do profile = 0, 7
    call check(evaluate(pos, profile) == 0, 'symmetric material and placement must balance')
  end do
  call check(parse_fen(passed, pos), 'passed pawn fixture is invalid')
  call check(game_phase(pos) == 0, 'a pawn ending must use pure endgame weights')
  call check(bonus(passed, pawns_eval) > bonus(contested, pawns_eval), 'adjacent enemy pawn ahead prevents a passer')
  call check(bonus(unblocked, pawns_eval) > bonus(blocked, pawns_eval), 'blocked passer must get a smaller bonus')
  call check(bonus(connected, pawns_eval) > bonus(doubled, pawns_eval), 'connected pawns avoid structural penalties')
  call check(bonus(passed, safety_eval) == 0, 'shelter must vanish in pure pawn endings')
  call check(bonus(sheltered, safety_eval) > bonus(exposed, safety_eval), 'friendly shield should shelter the king')
  call check(bonus('4k3/8/8/8/3N4/8/8/4K3 w - - 0 1', mobility_eval) > &
    bonus('4k3/8/8/8/N7/8/8/4K3 w - - 0 1', mobility_eval), 'central knight has more destinations')
  call check(bonus('4k3/p7/8/8/3N4/8/8/4K3 w - - 0 1', mobility_eval) > &
    bonus('4k3/8/4p3/8/3N4/8/8/4K3 w - - 0 1', mobility_eval), 'enemy pawn pressure removes destinations')

  call check(parse_fen(terms, pos), 'feature fixture is invalid')
  call check(parse_fen(reflected, mirror), 'reflected feature fixture is invalid')
  call check(game_phase(pos) == 7, 'phase must count both armies')
  do profile = 0, 7
    pos%turn = white
    score = evaluate(pos, profile)
    call check(score == evaluate(mirror, profile), 'color reflection must preserve the side-to-move score')
    pos%turn = black
    call check(score == -evaluate(pos, profile), 'changing the side to move must negate evaluation')
  end do
  call check(evaluation_profile('all') == ior(pawns_eval, ior(mobility_eval, safety_eval)), &
    'all profile must select all three feature groups')

contains

  integer function bonus(fen, group)
    character(len=*), intent(in) :: fen
    integer, intent(in) :: group
    type(position) :: sample

    call check(parse_fen(fen, sample), 'invalid FEN: ' // fen)
    bonus = evaluate(sample, group) - evaluate(sample, tapered_eval)
  end function bonus

  subroutine check(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (condition) return
    write (error_unit, '(a)') message
    stop 1
  end subroutine check

end program evaluation_terms
