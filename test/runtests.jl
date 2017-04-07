using CamelCup

game = CamelCup.Game(6)
p, st = CamelCup.setup!(game)
while !game.over
    p, st = CamelCup.taketurn!(game, p[1].action)
    show(p)
end
p
st
p, st = CamelCup.taketurn!(game, CamelCup.TakeBet(CamelCup.Green))
p, st = CamelCup.taketurn!(game, CamelCup.Oasis(5, true))
p, st = CamelCup.taketurn!(game, CamelCup.Roll())



p, st = CamelCup.taketurn!(game, CamelCup.FinalBet(CamelCup.White, true))

p, st = CamelCup.taketurn!(game, CamelCup.Roll())
p, st = CamelCup.taketurn!(game, CamelCup.Roll())
p, st = CamelCup.taketurn!(game, CamelCup.Roll())
CamelCup.taketurn!(game, CamelCup.Roll())
