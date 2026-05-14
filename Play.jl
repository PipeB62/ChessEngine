include("Moves.jl")
using Random

function show_moves(moves)
    for (i,move) in enumerate(moves)
        println(i," ", move)
    end
end 

function main()
    playercolor = white
    computercolor = black
    game_state = initalize_board()
    display(game_state)
    println()
    
    for i in 1:100
        allmoves = get_all_moves(game_state)
        if length(allmoves)==0
            if game_state.check
                print("checkmate")
            else
                print("stalemate")
            end
            break
        end
        
        if game_state.turn == playercolor
            show_moves(allmoves)
            println("Choose a move")
            moveindex = parse(Int, readline())
        else
            moveindex = rand(1:length(allmoves))  
        end

        move = allmoves[moveindex]
        if game_state.turn == computercolor
            readline()
            println("\033c")
            println("Computer move: ", move)
        end
        make_move!(game_state,move)
        display(game_state)
    end

end
main()