include("Evaluation.jl")
using Random

function show_moves(moves)
    for (i,move) in enumerate(moves)
        println(i," ", move)
    end
end 

function pvc()
    playercolor = black
    computercolor = white
    game_state = initalize_board()
    display(game_state)
    println()
    
    for i in 1:100
        allmoves = get_legal_moves(game_state)
        if length(allmoves)==0
            if first(game_state.check_stack)
                print("checkmate")
            else
                print("stalemate")
            end
            break
        end
        show_moves(allmoves)
        if game_state.turn == playercolor
            
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
        
        print("Calculating... ")
        move, score = negamax2(game_state, 4)
        println("Done")
        readline()
        println("\033c")
        println(game_state.turn, " move: ", move, " score: ", score)

        make_move!(game_state,move)
        println(first(game_state.move_stack))
        display(game_state)

    end

end

function main()
    cvc()
    #pvc()
end
main()