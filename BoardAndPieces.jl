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


# function board_from_fen(fen_str::String)

#     """
#     Return game_state starting from position described by fen_str. 

#     Currently using "stubborn id's", meaning 1:16 id's are white, 17:32 are black
#     and 5 and 29 are white and black king respectively. This induces inneficiencies in the 
#     code. Whenever this is generalized updating this functions should give a speedup
#     """

#     # Parse FEN description comprised as follows: piece placement, side to move, castling ability, en passant target square, halfmove, fullmove
#     parts = split(fen_str)
#     placement = parts[1]
#     side_to_move = parts[2]
#     castling = length(parts) >= 3 ? parts[3] : "-"

#     # Initialize empty board
#     pieces = fill(no_piece, 64)
#     colors = fill(no_color, 64)

#     fen_char_to_piece = Dict(
#         'p' => pawn,   'n' => knight, 'b' => bishop,
#         'r' => rook,   'q' => queen,  'k' => king
#     )

#     # Fen starts at rank 8 (with black pieces) and on file 0 (so at a)
#     fen_rank = 8 
#     fen_file = 0 

#     for fen_char in placement
#         # Next line
#         if fen_char == '/'
#             fen_rank -= 1
#             fen_file = 0
        
#         # Empty squares
#         elseif isdigit(fen_char)
#             fen_file += parse(Int, fen_char)

#         # Occupied square
#         else
#             square = (fen_rank - 1) * 8 + fen_file + 1
#             pieces[square] = fen_char_to_piece[lowercase(fen_char)]
#             colors[square] = isuppercase(fen_char) ? white : black
#             fen_file += 1
#         end
#     end

#     # Building piece list by finding all pieces first, categorizing them into piece types
#     piece_list = zeros(Int, 32)

#     # Collect squares per color and piece type
#     white_squares = Dict(p => Int[] for p in instances(Piece) if p != no_piece)
#     black_squares = Dict(p => Int[] for p in instances(Piece) if p != no_piece)
#     for sq in 1:64
#         if pieces[sq] != no_piece
#             if colors[sq] == white
#                 push!(white_squares[pieces[sq]], sq)
#             else
#                 push!(black_squares[pieces[sq]], sq)
#             end
#         end
#     end

#     # Kings MUST be IDs 5 and 29 
#     piece_list[5]  = only(white_squares[king]) 
#     piece_list[29] = only(black_squares[king])

#     # White ids MUST be 1:16 and black 17:32
#     back_rank_non_king = [rook, knight, bishop, queen, bishop, knight, rook] 
#     white_non_king_ids = [1, 2, 3, 4, 6, 7, 8]
#     black_non_king_ids = [25, 26, 27, 28, 30, 31, 32]

#     # Sort pieces 
#     for p in [rook, knight, bishop, queen] sort!(white_squares[p]) end
#     for p in [rook, knight, bishop, queen] sort!(black_squares[p]) end

#     # Assign white pieces depending on existence
#     for (id, piece_type) in zip(white_non_king_ids, back_rank_non_king)
#         piece_list[id] = isempty(white_squares[piece_type]) ? 0 : popfirst!(white_squares[piece_type])
#     end

#     # Assign black pieces depending on existence
#     for (id, piece_type) in zip(black_non_king_ids, back_rank_non_king)
#         piece_list[id] = isempty(black_squares[piece_type]) ? 0 : popfirst!(black_squares[piece_type])
#     end

#     # Assign white pawns to IDs 9–16
#     sort!(white_squares[pawn])
#     for i in 1:8
#         piece_list[8 + i] = isempty(white_squares[pawn]) ? 0 : popfirst!(white_squares[pawn])
#     end

#     # Assign black pawns to IDs 17–24
#     sort!(black_squares[pawn])
#     for i in 1:8
#         piece_list[16 + i] = isempty(black_squares[pawn]) ? 0 : popfirst!(black_squares[pawn])
#     end

#     # UCI FEN strings indicate what castles are still possible. To include this in our positions we mark rooks 
#     # as having moved if they are no longer allowed to castle 
#     function revoke_if_missing(letter, square_str)
#         # If castling no longer possible
#         if !occursin(letter, castling)
#             # Find whatever piece is there
#             piece_pos = findfirst(==(chess_to_square(square_str)), piece_list)
#             # Add a movement to disable castling
#             if !isnothing(piece_pos)
#                 piece_move_count[piece_pos] = 1
#             end
#         end
#     end

#     piece_move_count = zeros(Int, 32)
#     revoke_if_missing('Q', "a1")
#     revoke_if_missing('K', "h1")
#     if !occursin('Q', castling) && !occursin('K', castling)
#         piece_move_count[5] = 1   # white king
#     end
#     revoke_if_missing('q', "a8")
#     revoke_if_missing('k', "h8")
#     if !occursin('q', castling) && !occursin('k', castling)
#         piece_move_count[29] = 1  # black king
#     end

#     # Assign who's turn it is
#     turn = side_to_move == "w" ? white : black

#     # Initialize a temporary game and look for check
#     move_stack = Stack{AbstractMove}()
#     temp_state = GameState(pieces, colors, piece_list, piece_move_count, turn, Stack{Bool}(), move_stack)
#     in_check = is_in_check(turn, temp_state)

#     # Initialize real check stack
#     check_stack = Stack{Bool}()
#     push!(check_stack, in_check)

#     return GameState(pieces, colors, piece_list, piece_move_count, turn, check_stack, move_stack)
# end

function board_from_fen(fen_str::String)

    """
    Return game_state starting from position described by fen_str. 

    Currently using "stubborn id's", meaning 1:16 id's are white, 17:32 are black
    and 5 and 29 are white and black king respectively. Back rank pieces are hardcoded
    to specific squares:
        White: 1=a1-rook, 2=b1-knight, 3=c1-bishop, 4=d1-queen, 5=e1-king, 6=f1-bishop, 7=g1-knight, 8=h1-rook
        Black: 25=a8-rook, 26=b8-knight, 27=c8-bishop, 28=d8-queen, 29=e8-king, 30=f8-bishop, 31=g8-knight, 32=h8-rook
        White pawns: 9-16
        Black pawns: 17-24
    If a piece is not on its home square, the first available piece of that type is used instead.
    """

    # Parse FEN description comprised as follows: piece placement, side to move, castling ability, en passant target square, halfmove, fullmove
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

    # FEN starts at rank 8 (with black pieces) and on file 0 (so at a)
    fen_rank = 8 
    fen_file = 0 

    for fen_char in placement
        # Next line
        if fen_char == '/'
            fen_rank -= 1
            fen_file = 0
        
        # Empty squares
        elseif isdigit(fen_char)
            fen_file += parse(Int, fen_char)

        # Occupied square
        else
            square = (fen_rank - 1) * 8 + fen_file + 1
            pieces[square] = fen_char_to_piece[lowercase(fen_char)]
            colors[square] = isuppercase(fen_char) ? white : black
            fen_file += 1
        end
    end

    # Helper: assign a piece id, preferring the home square but falling back to first available
    function assign_piece(piece_list, candidate_squares, home_square, id)
        if home_square in candidate_squares
            piece_list[id] = home_square
            filter!(x -> x != home_square, candidate_squares)
        elseif !isempty(candidate_squares)
            piece_list[id] = popfirst!(candidate_squares)
        else
            piece_list[id] = 0
        end
    end

    piece_list = zeros(Int, 32)

    # White pieces
    wr = sort([sq for sq in 1:64 if pieces[sq] == rook   && colors[sq] == white])
    wn = sort([sq for sq in 1:64 if pieces[sq] == knight && colors[sq] == white])
    wb = sort([sq for sq in 1:64 if pieces[sq] == bishop && colors[sq] == white])
    wq = sort([sq for sq in 1:64 if pieces[sq] == queen  && colors[sq] == white])

    assign_piece(piece_list, wr, chess_to_square("a1"), 1)
    assign_piece(piece_list, wn, chess_to_square("b1"), 2)
    assign_piece(piece_list, wb, chess_to_square("c1"), 3)
    assign_piece(piece_list, wq, chess_to_square("d1"), 4)
    piece_list[5] = only(filter(sq -> pieces[sq] == king && colors[sq] == white, 1:64))
    assign_piece(piece_list, wb, chess_to_square("f1"), 6)
    assign_piece(piece_list, wn, chess_to_square("g1"), 7)
    assign_piece(piece_list, wr, chess_to_square("h1"), 8)

    # White pawns: ids 9-16
    wp = sort([sq for sq in 1:64 if pieces[sq] == pawn && colors[sq] == white])
    for i in 1:8
        piece_list[8 + i] = i <= length(wp) ? wp[i] : 0
    end

    # Black pieces
    br = sort([sq for sq in 1:64 if pieces[sq] == rook   && colors[sq] == black])
    bn = sort([sq for sq in 1:64 if pieces[sq] == knight && colors[sq] == black])
    bb = sort([sq for sq in 1:64 if pieces[sq] == bishop && colors[sq] == black])
    bq = sort([sq for sq in 1:64 if pieces[sq] == queen  && colors[sq] == black])

    assign_piece(piece_list, br, chess_to_square("a8"), 25)
    assign_piece(piece_list, bn, chess_to_square("b8"), 26)
    assign_piece(piece_list, bb, chess_to_square("c8"), 27)
    assign_piece(piece_list, bq, chess_to_square("d8"), 28)
    piece_list[29] = only(filter(sq -> pieces[sq] == king && colors[sq] == black, 1:64))
    assign_piece(piece_list, bb, chess_to_square("f8"), 30)
    assign_piece(piece_list, bn, chess_to_square("g8"), 31)
    assign_piece(piece_list, br, chess_to_square("h8"), 32)

    # Black pawns: ids 17-24
    bp = sort([sq for sq in 1:64 if pieces[sq] == pawn && colors[sq] == black])
    for i in 1:8
        piece_list[16 + i] = i <= length(bp) ? bp[i] : 0
    end

    # UCI FEN strings indicate what castles are still possible. To include this in our positions we mark rooks 
    # as having moved if they are no longer allowed to castle 
    piece_move_count = zeros(Int, 32)

    function revoke_if_missing(letter, piece_id)
        if !occursin(letter, castling)
            if piece_list[piece_id] > 0
                piece_move_count[piece_id] = 1
            end
        end
    end

    revoke_if_missing('Q', 1)   # white queenside rook (a1)
    revoke_if_missing('K', 8)   # white kingside rook  (h1)
    if !occursin('Q', castling) && !occursin('K', castling)
        piece_move_count[5] = 1   # white king
    end
    revoke_if_missing('q', 25)  # black queenside rook (a8)
    revoke_if_missing('k', 32)  # black kingside rook  (h8)
    if !occursin('q', castling) && !occursin('k', castling)
        piece_move_count[29] = 1  # black king
    end

    # Assign who's turn it is
    turn = side_to_move == "w" ? white : black

    # Initialize a temporary game and look for check
    move_stack = Stack{AbstractMove}()
    temp_state = GameState(pieces, colors, piece_list, piece_move_count, turn, Stack{Bool}(), move_stack)
    in_check = is_in_check(turn, temp_state)

    # Initialize real check stack
    check_stack = Stack{Bool}()
    push!(check_stack, in_check)

    return GameState(pieces, colors, piece_list, piece_move_count, turn, check_stack, move_stack)
end

function main()
    game_state = initalize_board()
    display(game_state)
end
#main()

