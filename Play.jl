include("Evaluation.jl")
using Random

function show_moves(moves)
    for (i,move) in enumerate(moves)
        println(i," ", move)
    end
end 

function pvc()
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

function cvc()

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
        
        move = negamax(game_state, 4)
        readline()
        println("\033c")
        println(game_state.turn, " move: ", move)

        make_move!(game_state,move)
        display(game_state)

        #consistensy check
        vision_graph_check = create_vision_graph(game_state.board, game_state.pieces)
        println("Vision graph consistent: ",vision_graph_check==game_state.vision_graph)
    end

end

function main()
    cvc()
    #pvc()
end
main()