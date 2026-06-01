using DataStructures

@enum Color no_color=0 white=1 black=2
@enum Piece no_piece=0 pawn=1 rook=2 knight=3 bishop=4 queen=5 king=6

abstract type AbstractMove end

global const mailbox = Int[
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1,  1,  2,  3,  4,  5,  6,  7,  8, -1,
    -1,  9, 10, 11, 12, 13, 14, 15, 16, -1,
    -1, 17, 18, 19, 20, 21, 22, 23, 24, -1,
    -1, 25, 26, 27, 28, 29, 30, 31, 32, -1,
    -1, 33, 34, 35, 36, 37, 38, 39, 40, -1,
    -1, 41, 42, 43, 44, 45, 46, 47, 48, -1,
    -1, 49, 50, 51, 52, 53, 54, 55, 56, -1,
    -1, 57, 58, 59, 60, 61, 62, 63, 64, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
]

global const mailbox64 = Int[
    22, 23, 24, 25, 26, 27, 28, 29,
    32, 33, 34, 35, 36, 37, 38, 39,
    42, 43, 44, 45, 46, 47, 48, 49,
    52, 53, 54, 55, 56, 57, 58, 59,
    62, 63, 64, 65, 66, 67, 68, 69,
    72, 73, 74, 75, 76, 77, 78, 79,
    82, 83, 84, 85, 86, 87, 88, 89,
    92, 93, 94, 95, 96, 97, 98, 99,
]

mutable struct GameState
    pieces::Vector{Piece} #64 elements
    colors::Vector{Color} #64 elements
    piece_list::Vector{Int} #32 elements. One for each piece. has position of each piece
    piece_move_count::Vector{Int} #32 elements
    turn::Color
    check_stack::Stack{Bool}
    move_stack::Stack{AbstractMove}
end

function get_file(square::Int)
    return square % 8 > 0 ? square % 8 : 8 
end

function get_rank(square::Int)
    return ceil(Int, square/8)
end

global const FILE_LETTERS = ["a", "b", "c", "d", "e", "f", "g", "h"]
function square_to_chess(square::Int) #For display 

    file_num = get_file(square)
    file = FILE_LETTERS[file_num]
    rank = string(get_rank(square))

    return file*rank
end

function print_matrix_no_quotes(mat::AbstractMatrix{<:AbstractString}) #For display
    for row in eachrow(mat)
        println(join(row, "  "))
    end
end

function get_piece_letter(piece::Piece)
    if piece == pawn 
        return "p"
    elseif piece == rook 
        return "r"
    elseif piece == knight 
        return "n"
    elseif piece == bishop 
        return "b"
    elseif piece == queen 
        return "q"
    elseif piece == king
        return "k"
    end
end

function Base.show(io::IO, game_state::GameState) #Display game state
    string_board = fill("x",(8,8))
    for sq in game_state.piece_list
        if sq>0
            piece = game_state.pieces[sq]
            piece_letter = get_piece_letter(piece)
            if game_state.colors[sq]==black
                piece_letter = uppercase(piece_letter)
            end
            string_board[sq] = piece_letter
        end
    end
    print_matrix_no_quotes(string_board)
    println("Turn: ",game_state.turn)
    println("Check: ",first(game_state.check_stack))
end 

function get_opposite_color(color::Color)
    if color == white
        return black
    else
        return white
    end
end

function get_king_id(color::Color)
    if color == white
        return 5
    else
        return 29
    end
end

function initalize_board()
    
    pieces = fill(no_piece,64)
    pieces[1:8] .= [rook, knight, bishop, queen, king, bishop, knight, rook]
    pieces[9:16] .= pawn
    pieces[49:56] .= pawn 
    pieces[57:64] .= [rook, knight, bishop, queen, king, bishop, knight, rook]

    colors = fill(no_color,64)
    colors[1:16] .= white
    colors[49:64] .= black

    piece_list = [i for i in 1:16] #white pieces are in squares 1:16
    append!(piece_list, [i for i in 49:64]) #black pieces are in squares 49:64

    piece_move_count= zeros(Int, 32)

    #Initialize check stack
    check_stack = Stack{Bool}()
    push!(check_stack, false)
    
    #Initialize move stack
    move_stack = Stack{AbstractMove}()

    game_state = GameState(pieces, colors, piece_list, piece_move_count, white, check_stack, move_stack)

    return game_state

end

function main()
    game_state = initalize_board()
    display(game_state)
end
#main()

