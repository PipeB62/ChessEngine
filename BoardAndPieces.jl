using Graphs

@enum PieceColor white=1 black=2
@enum PieceType pawn=1 rook=2 knight=3 bishop=4 queen=5 king=6
global const UP=CartesianIndex(0,1) 
global const DOWN=CartesianIndex(0,-1)
global const RIGHT=CartesianIndex(1,0)
global const LEFT=CartesianIndex(-1,0)

global const ROW_LETTERS = ["a","b","c","d","e","f","g","h"]

abstract type AbstractMove end

struct Piece 
    color::PieceColor
    type::PieceType 
end

mutable struct GameState
    board::Matrix{Int8}
    pieces::Vector{Union{Missing,Piece}}
    vision_graph::SimpleDiGraph
    turn::PieceColor
    check::Bool
    last_move::Union{Nothing,AbstractMove}
    pieces_move_count::Vector{Int}
end

function cartesian_to_chess(square::CartesianIndex) #For display 
    row = ROW_LETTERS[square[1]]
    column = string(square[2])

    return row*column
end

function id_to_chess(piece_id, pieces) #For display 

    piece = pieces[piece_id]
    if piece.type == pawn 
        letter = "p"
    elseif piece.type == rook
        letter = "r"
    elseif  piece.type == knight
        letter = "n" 
    elseif  piece.type == bishop
        letter = "b"
    elseif  piece.type == queen
        letter = "q"
    elseif  piece.type == king
        letter = "k"
    end

    if piece.color == black
        letter = uppercase(letter)
    end

    return letter

end

function print_matrix_no_quotes(mat::AbstractMatrix{<:AbstractString}) #For display
    for row in eachrow(mat)
        println(join(row, "  "))
    end
end

function Base.show(io::IO, game_state::GameState) #Display game state
    string_board = fill("x",(8,8))
    for i in CartesianIndices(string_board)
        if game_state.board[i]>0
            string_board[i] = id_to_chess(game_state.board[i], game_state.pieces)
        end
    end
    print_matrix_no_quotes(string_board)
    print("Turn: ",game_state.turn)
end 

function get_king_id(color::PieceColor)
    if color == white
        king_id = 5
    else
        king_id = 29
    end
    return king_id
end

function get_opposite_color(color::PieceColor)
    if color == white
        return black
    else
        return white
    end
end

function trace(initial_position, direction, board) #Ray tracing to get the vision of a piece
    board_domain = CartesianIndices(board)
    vision = CartesianIndex{2}[]
    for i in 1:8 
        square = initial_position + i*direction
        if square in board_domain
            push!(vision, square)
        else
            break
        end

        if board[square] > 0 #square is occupied
            break
        end
    end

    return vision
end

function calculate_vision(piece_id,board,pieces)
    piece = pieces[piece_id] #Get piece from piece id
    position = findall(x -> x==piece_id, board) #get position of the piece on the board
    if length(position) == 0
        throw(ErrorException("Piece is not on the board"))
    elseif length(position) > 1
        throw(ErrorException("The board has duplicate piece ids"))
    end
    position = position[1]
    board_domain = CartesianIndices(board) #List of the cartesian indices of the board

    if piece.type == pawn 
        if piece.color == white
            displacements = [UP+RIGHT,UP+LEFT]
        else
            displacements = [DOWN+RIGHT,DOWN+LEFT]
        end
        vision = filter(x->(x in board_domain), position .+ displacements)
        
    elseif piece.type == rook

        directions = [UP,DOWN,LEFT,RIGHT]
        vision = CartesianIndex{2}[]

        for direction in directions
            dirvision = trace(position,direction,board)
            append!(vision,dirvision)
        end
        return vision

    elseif piece.type == knight
        displacements = [UP+UP+RIGHT,UP+UP+LEFT,
                         RIGHT+RIGHT+UP,RIGHT+RIGHT+DOWN,
                         LEFT+LEFT+UP, LEFT+LEFT+DOWN,
                         DOWN+DOWN+LEFT, DOWN+DOWN+RIGHT]
        vision = filter(x->(x in board_domain), position .+ displacements)

    elseif piece.type == bishop
        directions = [UP+RIGHT, UP+LEFT, DOWN+RIGHT, DOWN+LEFT]
        vision = CartesianIndex{2}[]

        for direction in directions
            dirvision = trace(position,direction,board)
            append!(vision,dirvision)
        end
        return vision

    elseif piece.type == queen
        directions = [UP,DOWN,LEFT,RIGHT,
                      UP+RIGHT, UP+LEFT, DOWN+RIGHT, DOWN+LEFT]
        vision = CartesianIndex{2}[]

        for direction in directions
            dirvision = trace(position,direction,board)
            append!(vision,dirvision)
        end
        return vision

    elseif piece.type == king
        displacements = [UP,DOWN,LEFT,RIGHT,
                         UP+RIGHT, UP+LEFT, DOWN+RIGHT, DOWN+LEFT]
        vision = filter(x->(x in board_domain), position .+ displacements)
    end

    return vision

end

function create_vision_graph(board,pieces)
    #Initialize vision graph
    vision_graph = SimpleDiGraph()
    add_vertices!(vision_graph, 32) #One vertex for each piece : piece vertices (1 to 32)
    add_vertices!(vision_graph, 64) #One vertex for each square : square vertices (33 to 96)

    for i in 1:64 #Iterate over the 64 squares (linear indices)
        piece_id = board[i]
        if piece_id>0 #if the square is occupied
            add_edge!(vision_graph,i+32,piece_id) #Square vertex points to the piece vertex corresponding to the piece that occupies that square on the board

            visionCI = calculate_vision(piece_id,board,pieces) #vision in cartesian indices
            visionLI = LinearIndices(board)[visionCI] #vision in linear indices

            for square_index in visionLI
                add_edge!(vision_graph,piece_id,square_index+32) #Piece vertex points to the square vertices corresponding to the squares that it "sees"
            end
        end
    end

    return vision_graph
end

function initalize_board()
    
    pieces = Vector{Union{Missing,Piece}}(missing,32)

    #white pieces
    for i in 1:16
        pieces[i] = Piece(white,pawn)
    end
    pieces[1] = Piece(white,rook)
    pieces[8] = Piece(white,rook)

    pieces[2] = Piece(white,knight)
    pieces[7] = Piece(white,knight)

    pieces[3] = Piece(white,bishop)
    pieces[6] = Piece(white,bishop)

    pieces[4] = Piece(white,queen)
    pieces[5] = Piece(white,king)

    #black pieces
    for i in 17:24 
        pieces[i] = Piece(black,pawn)
    end
    pieces[25] = Piece(black,rook)
    pieces[32] = Piece(black,rook)

    pieces[26] = Piece(black,knight)
    pieces[31] = Piece(black,knight)

    pieces[27] = Piece(black,bishop)
    pieces[30] = Piece(black,bishop)

    pieces[28] = Piece(black,queen)
    pieces[29] = Piece(black,king)

    #Put pieces in the board
    board = zeros(Int8,8,8)
    
    board[:,1] = 1:8
    board[:,2] = 9:16
    board[:,7] = 17:24
    board[:,8] = 25:32

    #Initialize vision graph
    vision_graph = create_vision_graph(board,pieces)

    #Initialize pieces move pieces_move_count 
    pieces_move_count = zeros(Int, 32)

    game_state = GameState(board, pieces, vision_graph, white, false, nothing, pieces_move_count)

    return game_state

end

function get_square_vision(piece_id, vision_graph) #includes occupied squares
    visionLI = outneighbors(vision_graph, piece_id) .- 32 #vision in linear index. 
    visionCI = CartesianIndices((8,8))[visionLI] #Convert to cartesian index

    return visionCI
end

function get_piece_vision(piece_id, vision_graph)
    piece_vision = [node for node in BFSIterator(vision_graph, piece_id; depth_limit=2, neighbors_type=outneighbors)]
    s = ceil(Int, length(piece_vision)/2)+1
    piece_vision = piece_vision[s:end]
    return piece_vision
end

function is_seen_by(piece_id::Int, vision_graph) 
    #Returns piece_ids of pieces that see input piece

    seenby = [node for node in BFSIterator(vision_graph, piece_id; depth_limit=2, neighbors_type=inneighbors)] #Traverse graph in depth 2 in opposite direction
    seenby = seenby[3:end] #Remove first 2 nodes corresponding to piece_id and to the square it occupies

    return seenby
end

function is_seen_by(square::CartesianIndex, vision_graph)
    #Returns piece_ids of pieces that see input square

    square_vertex = LinearIndices((8,8))[square] + 32
    seenby = inneighbors(vision_graph, square_vertex)
    seenby = [i for i in seenby]

    return seenby
end

function get_position(piece_id, board)
    position = findall(x->x==piece_id, board)
    if length(position)>1
        throw(ErrorException("The board has duplicate piece ids"))
    end
    return position[1]
end

function main()
    game_state = initalize_board()
    display(game_state)
end
#main()

