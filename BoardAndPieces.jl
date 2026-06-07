using DataStructures

@enum Color no_color=0 white=1 black=2
@enum Piece no_piece=0 pawn=1 rook=2 knight=3 bishop=4 queen=5 king=6

abstract type AbstractMove end
global const FILE_LETTERS = ["a", "b", "c", "d", "e", "f", "g", "h"]
global const FILE_NUMBERS = Dict(
        'a' => 1,   'b' => 2, 'c' => 3, 'd' => 4,
        'e' => 5,   'f' => 6, 'g' => 7, 'h' => 8,
    )


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
    piece_move_count::Vector{Int} #32 elements. Number of times each piece has moved. index is piece_id
    turn::Color #Current turn
    check_stack::Stack{Bool}
    move_stack::Stack{AbstractMove}
end
#Extract check or last_move using first(check_stack) or first(move_stack)
#Using a stack for unmake move

function get_file(square::Int) # abc
    return square % 8 > 0 ? square % 8 : 8
end

function get_rank(square::Int) # 123
    return ceil(Int, square/8)
end

function square_to_chess(square::Int) #For display 
    """
    Takes input a square (int between 1 and 64) and returns a string in chess notation (eg e4)
    """
    file_num = get_file(square)
    file = FILE_LETTERS[file_num]
    rank = string(get_rank(square))

    return file*rank
end

function chess_to_square(chess_str)
    """
    Takes input a chess coordinate (eg e4) and returns a square (int between 1 and 64)
    """
    rank = parse(Int, string(chess_str[2]))
    file = FILE_NUMBERS[chess_str[1]]

    return 8 * (rank - 1) + file
end


function print_matrix_no_quotes(mat::AbstractMatrix{<:AbstractString}) #For display
    for row in eachrow(mat)
        println(join(row, "  "))
    end
end

function get_letter_from_piece(piece::Piece)::String
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

function get_piece_from_letter(letter::String)
    if letter == "p" 
        return pawn
    elseif letter == "r" 
        return rook
    elseif letter == "n" 
        return knight
    elseif letter == "b" 
        return bishop
    elseif letter == "q" 
        return queen
    elseif letter == "k"
        return king
    end
end

function Base.show(io::IO, game_state::GameState) #Display game state
    string_board = fill("x",(8,8))
    for sq in game_state.piece_list
        if sq>0
            piece = game_state.pieces[sq]
            piece_letter = get_letter_from_piece(piece)
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
    """
    Return game_state in initial position
    """
    
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


function board_from_fen(fen_str::String)
    
    """
    Return game_state starting from position described by fen_str.

    FUNCTION NOT FINISHED AND THUS NOT YET USED
    """

    # FEN description is comprised as follows: piece placement, side to move, castling ability, en passant target square, halfmove, fullmove
    parts = split(fen_str)
    placement = parts[1]
    side_to_move = parts[2]
    castling = length(parts) >= 3 ? parts[3] : "-"

    # Initialize empty board
    pieces = fill(no_piece, 64)
    colors = fill(no_color, 64)

    fen_char_to_piece = Dict(
        'p' => pawn,   'n' => knight, 'b' => bishop,
        'r' => rook,   'q' => queen,  'k' => king
    )

    # Fen starts at rank 8 (with black pieces) and on file 0 (so at a)
    fen_rank = 8  
    fen_file = 0  

    for fen_char in placement
        # New line 
        if fen_char == '/' 
            fen_rank -= 1
            fen_file = 0

        # Empty squares
        elseif isdigit(fen_char)
            fen_file += parse(Int, fen_char)

        # Piece
        else
            square = (fen_rank - 1) * 8 + fen_file + 1
            pieces[square] = fen_char_to_piece[lowercase(fen_char)]
            colors[square] = isuppercase(fen_char) ? white : black
            fen_file += 1

        end
    end


    # TODO: MISSING PART THAT CREATES THE PIECE_LIST. FOR NOW WE DON'T HAVE FEN FUNCTIONALITY

    # Initially no pieces have moved
    piece_move_count = zeros(Int, 32)

    # To turn off castling rights we add a 1 "moved_counter" to the rooks and/or kings depending on rights
    if !occursin('Q', castling)  
        piece_move_count[1] = 1   # a1 rook
    end
    if !occursin('K', castling)  
        piece_move_count[8] = 1   # h1 rook
    end
    if !occursin('K', castling) && !occursin('Q', castling)
        piece_move_count[5] = 1   # white king
    end
    if !occursin('q', castling)  
        piece_move_count[25] = 1  # a8 rook
    end
    if !occursin('k', castling) 
        piece_move_count[32] = 1  # h8 rook
    end
    if !occursin('k', castling) && !occursin('q', castling)
        piece_move_count[29] = 1  # black king
    end

    # Assign who's turn it is
    turn = side_to_move == "w" ? white : black

    #Initialize check stack
    check_stack = Stack{Bool}()
    push!(check_stack, false)

    #Initialize move stack
    move_stack = Stack{AbstractMove}()

    return GameState(pieces, colors, piece_list, piece_move_count, turn, check_stack, move_stack)
end

function main()
    game_state = initalize_board()
    display(game_state)
end
#main()

