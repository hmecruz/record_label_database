from flask import Blueprint, request, jsonify, abort
from config.database_config import DatabaseConfig
import pyodbc

songs_api = Blueprint('songs_api', __name__, url_prefix='/api/songs')

def map_row_to_song(row):
    """
    Convert a row from vw_Songs into a JSON-serializable dict.
    Columns: SongID, Title, Duration, ReleaseDate, Genres, Contributors, CollaborationName
    """
    return {
        "SongID":            row.SongID,
        "Title":             row.Title,
        "Duration":          row.Duration,
        "ReleaseDate":       row.ReleaseDate.isoformat() if row.ReleaseDate else None,
        "Genres":            row.Genres or "",
        "Contributors":      row.Contributors or "",
        "CollaborationName": row.CollaborationName or ""
    }

@songs_api.route('', methods=['GET'])
def list_songs():
    # read optional filters
    title         = request.args.get('title')
    min_duration  = request.args.get('minDuration', type=int)
    max_duration  = request.args.get('maxDuration', type=int)
    release_date  = request.args.get('releaseDate')  # expect YYYY-MM-DD
    genre         = request.args.get('genre')
    contributor   = request.args.get('contributor')
    collaboration = request.args.get('collaboration')

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_GetSongs "
            "@Title=?, @MinDuration=?, @MaxDuration=?, @ReleaseDate=?, "
            "@Genre=?, @Contributor=?, @Collaboration=?",
            title, min_duration, max_duration, release_date,
            genre, contributor, collaboration
        )
        rows = cursor.fetchall()
        songs = [map_row_to_song(r) for r in rows]
        return jsonify(songs), 200
    finally:
        conn.close()

@songs_api.route('/<int:song_id>', methods=['GET'])
def get_song(song_id):
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_GetSongByID @ID=?",
            song_id
        )
        row = cursor.fetchone()
        if not row:
            abort(404, description=f"Song with ID {song_id} not found")
        return jsonify(map_row_to_song(row)), 200
    finally:
        conn.close()

@songs_api.route('', methods=['POST'])
def create_song():
    data = request.get_json() or {}
    # required fields
    required = ['Title', 'Duration', 'ReleaseDate']
    missing = [f for f in required if data.get(f) is None]
    if missing:
        abort(400, description=f"Missing required fields: {', '.join(missing)}")

    title             = data['Title']
    duration          = data['Duration']
    release_date      = data['ReleaseDate']
    genres            = data.get('Genres')
    contributors      = data.get('Contributors')
    collaboration     = data.get('CollaborationName')

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        result = cursor.execute(
            "DECLARE @NewID INT; "
            "EXEC dbo.sp_CreateSong "
            "@Title=?,@Duration=?,@ReleaseDate=?,"
            "@Genres=?,@Contributors=?,@CollaborationName=?,"
            "@NewID=@NewID OUTPUT; SELECT @NewID AS NewID;",
            title, duration, release_date,
            genres, contributors, collaboration
        )
        new_id = result.fetchone().NewID
        conn.commit()
    except pyodbc.Error as e:
        conn.rollback()
        abort(400, description=str(e))
    finally:
        conn.close()

    return get_song(new_id)

@songs_api.route('/<int:song_id>', methods=['PUT'])
def update_song(song_id):
    data = request.get_json() or {}
    required = ['Title', 'Duration', 'ReleaseDate']
    missing = [f for f in required if data.get(f) is None]
    if missing:
        abort(400, description=f"Missing required fields: {', '.join(missing)}")

    title             = data['Title']
    duration          = data['Duration']
    release_date      = data['ReleaseDate']
    genres            = data.get('Genres')
    contributors      = data.get('Contributors')
    collaboration     = data.get('CollaborationName')

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "EXEC dbo.sp_UpdateSong "
                "@ID=?,@Title=?,@Duration=?,@ReleaseDate=?,"
                "@Genres=?,@Contributors=?,@CollaborationName=?",
                song_id, title, duration, release_date,
                genres, contributors, collaboration
            )
            conn.commit()
        except pyodbc.ProgrammingError as pe:
            # No custom error thrown - rely on SELECT ROWCOUNT check above
            abort(404, description=f"Song with ID {song_id} not found")
    finally:
        conn.close()

    return get_song(song_id)

@songs_api.route('/<int:song_id>', methods=['DELETE'])
def delete_song(song_id):
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "EXEC dbo.sp_DeleteSong @ID=?",
                song_id
            )
            conn.commit()
        except pyodbc.ProgrammingError as pe:
            abort(404, description=f"Song with ID {song_id} not found")
        return '', 204
    finally:
        conn.close()
