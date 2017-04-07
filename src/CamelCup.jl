module CamelCup

const tilemarkers = Dict(
    7=>38,
    8=>44,
    9=>50,
    10=>56,
    11=>62,
    6=>128,
    12=>152,
    5=>192,
    13=>216,
    4=>256,
    14=>280,
    3=>320,
    2=>326,
    1=>332,
    16=>338,
    15=>344
)

const gameboard = """
_______________________________
|     |     |     |     |     |
|-----|‾‾8‾‾‾‾‾9‾‾‾‾10‾‾|-----|
|     |6              12|     |
|-----|                 |-----|
|     |5              13|     |
|-----|                 |-----|
|     |4              14|     |
|-----|__2_____1____16__|-----|
|     |     |     |     |     |
‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
"""

# type Tile
#     val::UInt64
# end
#
# function Base.length(t::Tile)
#
# end
#
# function Base.append!(t::Tile, v::UInt64)
#
# end
#
# function Base.prepend!(t::Tile, v::UInt64)
#
# end
#
# function Base.splice!(t::Tile, rng)
#
# end
#
# function getlast(t::Tile)
#
# end
#
# function getfirst(t::Tile)
#
# end
#
# function get2ndlast(t::Tile)

using Combinatorics, Iterators

const LAST_TILE = 16
const FINAL_PAYOUT = [8, 5, 3, 2, 1]

@enum Camel Orange=1 Green Blue White Yellow
Base.getindex{T}(A::Vector{T}, c::Camel) = getindex(A, Int(c))
Base.setindex!{T}(A::Vector{T}, x, c::Camel) = setindex!(A, x, Int(c))
function indexof(A::Vector, c::Camel)
    A[1] == c && return 1
    A[2] == c && return 2
    A[3] == c && return 3
    A[4] == c && return 4
    A[5] == c && return 5
end

const letterabbr = Dict(Orange=>'O', Green=>'G', Blue=>'B', White=>'W', Yellow=>'Y')

abstract Action

type TakeBet <: Action
    player::Int
    camel::Camel
    amount::Int
    TakeBet(c::Camel) = (n = new(); n.camel = c; return n)
    TakeBet(c::Camel, a::Int) = (n = new(); n.camel = c; n.amount = a; return n)
end

type Roll <: Action
    player::Int
    Roll() = new()
end

type FinalBet <: Action
    player::Int
    camel::Camel
    winner::Bool
    FinalBet(c::Camel, w::Bool) = (n = new(); n.camel = c; n.winner = w; return n)
end

type Oasis <: Action
    player::Int
    tile::Int
    oasis::Bool
    Oasis(t::Int, o::Bool) = (n = new(); n.tile = t; n.oasis = o; return n)
end

type Game
    n::Int # number of players
    ct::Int # current player's turn
    dice::Vector{Camel}
    camels::Vector{Int} # tracks the current tile for each camel
    tiles::Dict{Int, Vector{Camel}} # maps a tile # to camel's on it
    oases::Dict{Int, Oasis} # maps a tile # to an Oasis
    moneys::Vector{Int} # track current $ for each player
    availablebets::Vector{Int} # tracks which bets are available by color
    playerbets::Dict{Int, Vector{TakeBet}} # tracks leg betting tiles that players take
    finalguesses::Vector{FinalBet}
    actionlog::Vector{Action}
    over::Bool
end

Game(n) = Game(n, 1,
    collect(instances(Camel)),
    zeros(Int, 5),
    Dict{Int, Vector{Camel}}(),
    Dict{Int, Oasis}(),
    fill(3, n),
    fill(5, 5),
    Dict{Int, Vector{TakeBet}}(),
    FinalBet[],
    Action[],
    false)

function roll!(game)
    die = splice!(game.dice, rand(1:length(game.dice)))
    val = rand(1:3)
    return die, val
end

function setup!(game)
    for i in instances(Camel)
        die, val = roll!(game)
        push!(get!(game.tiles, val, CamelCup.Camel[]), die)
        game.camels[die] = val
    end
    game.dice = collect(instances(Camel))
    println("Game setup complete:")
    printstate(game)
    return calculatenext(game)
end

function printstate(game)
    gb = deepcopy(gameboard.data)
    tiles = collect(keys(game.tiles))
    for t in tiles
        camels = game.tiles[t]
        st = tilemarkers[t]
        for c in camels
            gb[st] = letterabbr[c]
            st -= 1
        end
    end
    println(String(gb))
    return
end

function payout!(game, player, amount)
    game.moneys[player] = max(game.moneys[player] + amount, 0)
    println("Player #$(player) $(amount < 0 ? "loses -\$$(abs(amount))" : "gains \$$amount"), for a new total of \$$(game.moneys[player]).")
    return
end

function legscore!(game)
    # payout 1st place camel
    # payout 2nd place camel
    # payout any non-placing camel bets
    places = [(game.tiles[tile] for tile in sort(collect(keys(game.tiles))))...;]
    println("That's the end of the leg! $(places[end]) came in first, with $(places[end-1]) coming in second.")
    for (player, bets) in game.playerbets
        for bet in bets
            if bet.camel == places[end]
                print("\tPlayer $(bet.player) correctly bet on first-place finisher $(places[end]) 🤑 ! ")
                payout!(game, bet.player, bet.amount)
            elseif bet.camel == places[end-1]
                print("\tPlayer $(bet.player) correctly bet on second-place finisher $(places[end-1]) 🤑 ! ")
                payout!(game, bet.player, 1)
            else
                print("\tPlayer $(bet.player) incorrectly bet on $(bet.camel) 😢 . ")
                payout!(game, bet.player, -1)
            end
        end
    end
    empty!(game.playerbets)

    # clear oases
    empty!(game.oases)
    # reset leg betting tiles
    game.availablebets = fill(5, 5)
    # reset game dice
    game.dice = collect(instances(Camel))
    return
end

function endgame!(game)
    places = [(game.tiles[tile] for tile in sort(collect(keys(game.tiles))))...;]
    winnerindex = 1
    loserindex = 1
    println("That's the end of the game! $(places[end]) came in first, with $(places[1]) bringing up the rear.")
    for bet in game.finalguesses
        if bet.winner
            if bet.camel == places[end]
                print("\tPlayer $(bet.player) correctly bet on $(places[end]) for first place! ")
                payout!(game, bet.player, FINAL_PAYOUT[winnerindex])
                winnerindex += winnerindex == 5 ? 0 : 1
            else
                print("\tPlayer $(bet.player) incorrectly bet on $(bet.camel) for first place. ")
                payout!(game, bet.player, -1)
            end
        else
            if bet.camel == places[1]
                print("\tPlayer $(bet.player) correctly bet on $(places[1]) for last place! ")
                payout!(game, bet.player, FINAL_PAYOUT[loserindex])
                loserindex += loserindex == 5 ? 0 : 1
            else
                print("\tPlayer $(bet.player) incorrectly bet on $(bet.camel) for last place. ")
                payout!(game, bet.player, -1)
            end
        end
    end
    println("Final \$ Standings:")
    inds = sortperm(game.moneys, rev=true)
    for (i, p) in zip(inds, game.moneys[inds])
        println("\tPlayer $i: \$$p")
    end
    game.over = true
    return
end

function cleanup!(game)
    todelete = Int[]
    for (tile, camels) in game.tiles
        isempty(camels) && push!(todelete, tile)
    end
    foreach(x->delete!(game.tiles, x), todelete)
    return
end

# TakeBet, FinalBet, Roll, Oasis
function updatestate!(game, action::Roll)
    # roll the dice
    die, val = roll!(game)
    println("and decides to roll the dice. And the result is...$((string(die), val)).")
    payout!(game, action.player, 1)

    # move the camels
    tile = game.camels[die]
    cams = game.tiles[tile]
    movingcamels = splice!(cams, indexof(cams, die):length(cams))
    newtile = tile + val
    if haskey(game.oases, newtile)
        oasis = game.oases[newtile]
        println("$(movingcamels) landed on player $(oasis.player)'s oasis tile, which moves them $(oasis.oasis ? "forward" : "backward") an extra space.")
        newtile += oasis.oasis
        payout!(game, oasis.player, 1)
        if oasis.oasis
            append!(get!(game.tiles, newtile, Camel[]), movingcamels)
            foreach(x->game.camels[x] = newtile, movingcamels)
            cleanup!(game)
            println("Camel positions:")
            printstate(game)
        else
            prepend!(get!(game.tiles, newtile, Camel[]), movingcamels)
            foreach(x->game.camels[x] = newtile, movingcamels)
            cleanup!(game)
            println("Camel positions:")
            printstate(game)
        end
    else
        append!(get!(game.tiles, newtile, Camel[]), movingcamels)
        foreach(x->game.camels[x] = newtile, movingcamels)
        cleanup!(game)
        println("Camel positions:")
        printstate(game)
    end
    # end of leg (if applicable)
    isempty(game.dice) && legscore!(game)
    newtile > LAST_TILE && return endgame!(game)
    return
end

function updatestate!(game, action::TakeBet)
    # reduce availablebets
    amount = game.availablebets[action.camel]
    action.amount = amount
    println("and takes the \$$(amount) bet on the $(action.camel) camel.")
    game.availablebets[action.camel] = amount == 5 ? 3 : (amount == 3 ? 2 : 0)
    # update playerbets
    push!(get!(game.playerbets, action.player, TakeBet[]), action)
    return
end

function updatestate!(game, action::FinalBet)
    # update finalguesses
    push!(game.finalguesses, action)
    guesses = filter(x->x.winner == action.winner, game.finalguesses)
    println("and places a guess for the final $(action.winner ? "winner" : "loser"). $(length(guesses)) guesses have been placed so far.")
    return
end

function updatestate!(game, action::Oasis)
    # update oases
    println("and places $(action.oasis ? "an oasis" : "a desert") on tile #$(action.tile)")
    game.oases[action.tile] = action
    return
end

const ACTIONS = [TakeBet, FinalBet, Oasis]

type Payout{T <: Action}
    action::T
    expectedvalue::Float64
end

function calculatenext(game)
    possiblepayouts = Payout[Payout(Roll(), 1.0)]

    # maps Camel to [% 1st place, % 2nd place, % 3rd 4th or 5th place]
    standings = Dict(camel=>[0.0, 0.0, 0.0] for camel in instances(Camel))
    # maps Camel to [% 1st place, % 2nd 3rd 4th, % 5th place] for final
    finalstandings = Dict(camel=>[0.0, 0.0, 0.0] for camel in instances(Camel))
    oasispayouts = Dict{Int, Float64}() # maps tile # => expected value
    # find tiles w/o camel, w/o oasis and w/o oasis +-1 tile away
    lastcameltile = minimum(game.camels)
    potentialoases = filter!(x->x > lastcameltile, collect(setdiff!(IntSet(1:LAST_TILE), game.camels)))
    for tile in keys(game.oases)
        deleteat!(potentialoases, findin(potentialoases, [tile - 1, tile, tile + 1]))
    end
    for o in potentialoases
        oasispayouts[o] = 0.0 # Dict{Tuple{Int, Camel}, Float64}()
    end
    dice = game.dice[:]
    diceperms = permutations(dice)
    valperms = Iterators.product(repeated(1:3, length(dice))...)
    probability = 1 / (length(diceperms) * length(valperms))
    for diceperm in diceperms
        for valperm in valperms
            camels = deepcopy(game.camels)
            tiles = deepcopy(game.tiles)
            for (die, val) in zip(diceperm, valperm)
                tile = camels[die]
                cams = tiles[tile]
                movingcamels = splice!(cams, indexof(cams, die):length(cams))
                newtile = tile + val
                if haskey(game.oases, newtile)
                    oasis = game.oases[newtile]
                    newtile += oasis.oasis
                    if oasis.oasis
                        append!(get!(tiles, newtile, Camel[]), movingcamels)
                        foreach(x->camels[x] = newtile, movingcamels)
                    else
                        prepend!(get!(tiles, newtile, Camel[]), movingcamels)
                        foreach(x->camels[x] = newtile, movingcamels)
                    end
                else
                    if haskey(oasispayouts, newtile)
                        oasispayouts[newtile] += probability
                    end
                    append!(get!(tiles, newtile, Camel[]), movingcamels)
                    foreach(x->camels[x] = newtile, movingcamels)
                end
                if newtile > LAST_TILE
                    places = [(tiles[tile] for tile in sort(collect(keys(tiles))))...;]
                    for (i, camel) in enumerate(reverse(places))
                        finalstandings[camel][i == 1 ? 1 : i == 5 ? 3 : 2] += probability
                    end
                    break
                end
            end
            # update standings probabilities
            places = [(tiles[tile] for tile in sort(collect(keys(tiles))))...;]
            for (i, camel) in enumerate(reverse(places))
                standings[camel][min(i, 3)] += probability
            end
        end
    end

    # Oasis
    append!(possiblepayouts, (Payout(Oasis(k, true), x) for (k, x) in oasispayouts))

    # TakeBet
    for (i, bet) in enumerate(game.availablebets)
        bet == 0 && continue
        c = Camel(i)
        push!(possiblepayouts, Payout(TakeBet(c, bet), bet * standings[c][1] + standings[c][2] + (-1 * standings[c][3])))
    end
    # run thru all possible combinations of dice rolling thru end of game, tracking # of total scenarios and the # of times each camel ends up winning to get each camel's % chance of winning
    camelfinalpayouts = Dict(true=>fill(8, 5), false=>fill(8,5))
    winnerindexes = Dict(c=>2 for c in instances(Camel))
    loserindexes = Dict(c=>2 for c in instances(Camel))
    for bet in game.finalguesses
        camelfinalpayouts[bet.winner][bet.camel] = FINAL_PAYOUT[min(5, bet.winner ? winnerindexes[bet.camel] : loserindexes[bet.camel])]
        if bet.winner
            winnerindexes[bet.camel] += 1
        else
            loserindexes[bet.camel] += 1
        end
    end
    @show camelfinalpayouts
    @show finalstandings
    for camel in instances(Camel)
        for winner in (true, false)
            push!(possiblepayouts, Payout(FinalBet(camel, winner), camelfinalpayouts[winner][camel] * finalstandings[camel][winner ? 1 : 3]))
        end
    end

    foreach(x->x.action.player = game.ct, possiblepayouts)
    filter!(x->x.expectedvalue > 0.0, possiblepayouts)
    return sort!(possiblepayouts, by=x->x.expectedvalue, rev=true), standings
end

# logs what the current player did for their turn
# returns choices for next player's turn
# if a camel crosses the finish line, returns end game state + winner
function taketurn!(game, action)
    action.player = game.ct
    print("player #$(game.ct) takes their turn...")
    game.ct = mod1(game.ct + 1, game.n)
    updatestate!(game, action)
    printstate(game)
    game.over && return Payout[], Dict{Camel, Vector{Float64}}()
    return calculatenext(game)
end

end # module
