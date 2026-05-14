include("Moves.jl")

global const PIECE_VALUES = Dict(pawn=>1, bishop=>3, knight=>3, rook=>5, queen=>9, king=>200)

function piece_value(piece::Piece)
    if piece.color == white
        mult = 1
    else 
        mult = -1
    end

    return mult*PIECE_VALUES[piece.type]
end

function piece_balance(game_state::GameState)
    balance = 0
    for square_id in game_state.board
        if square_id>0
            balance += piece_value(game_state.pieces[square_id])
        end
    end

    return balance
end

function main()
    game_state = initalize_board()
    print(piece_balance(game_state))
end
main()