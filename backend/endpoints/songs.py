# backend/endpoints/songs.py

from flask import Blueprint, request, jsonify, abort
from config.database_config import DatabaseConfig
import pyodbc

songs_api = Blueprint('songs_api', __name__, url_prefix='/api/songs')


def map_row_to_song(row):
    """
    Convert a row from vw_Songs into a JSON‐serializable dict.
    Columns in vw_Songs: SongID, Title, Duration, ReleaseDate, Genres, Contributors, CollaborationName
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
    # Read optional filters from query string
    title         = request.args.get('title')
    min_duration  = request.args.get('minDuration', type=int)
    max_duration  = request.args.get('maxDuration', type=int)
    release_date  = request.args.get('releaseDate')  # expect YYYY-MM-DD or None
    genre         = request.args.get('genre')
    contributor   = request.args.get('contributor')
    collaboration = request.args.get('collaboration')

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_GetSongs "
            "@Title      = ?, "
            "@MinDuration= ?, "
            "@MaxDuration= ?, "
            "@ReleaseDate= ?, "
            "@Genre      = ?, "
            "@Contributor= ?, "
            "@Collaboration = ?",
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
            "EXEC dbo.sp_GetSongByID @ID = ?",
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

    # Required fields: Title, Duration
    missing = []
    if data.get('Title') is None:
        missing.append('Title')
    if data.get('Duration') is None:
        missing.append('Duration')
    if missing:
        abort(400, description=f"Missing required fields: {', '.join(missing)}")

    title        = data['Title']
    duration     = data['Duration']
    release_date = data.get('ReleaseDate')   # may be None
    genres       = data.get('Genres')        # comma-separated Person_NIFs or None
    contributors = data.get('Contributors')  # comma-separated Person_NIFs or None

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        result = cursor.execute(
            "DECLARE @NewID INT; "
            "EXEC dbo.sp_CreateSong "
            "@Title       = ?, "
            "@Duration    = ?, "
            "@ReleaseDate = ?, "
            "@Genres      = ?, "
            "@Contributors= ?, "
            "@NewID       = @NewID OUTPUT; "
            "SELECT @NewID AS NewID;",
            title, duration, release_date,
            genres, contributors
        )
        row = result.fetchone()
        new_id = row.NewID if row else None
        conn.commit()
    except pyodbc.Error as e:
        conn.rollback()
        # Return the raw error message for debugging; in production you might want to sanitize
        abort(400, description=str(e))
    finally:
        conn.close()

    if not new_id:
        abort(500, description="Failed to create song for unknown reasons.")
    return get_song(new_id)


@songs_api.route('/<int:song_id>', methods=['PUT'])
def update_song(song_id):
    data = request.get_json() or {}

    # Required fields: Title, Duration
    missing = []
    if data.get('Title') is None:
        missing.append('Title')
    if data.get('Duration') is None:
        missing.append('Duration')
    if missing:
        abort(400, description=f"Missing required fields: {', '.join(missing)}")

    title        = data['Title']
    duration     = data['Duration']
    release_date = data.get('ReleaseDate')   # may be None
    genres       = data.get('Genres')        # comma-separated or None
    contributors = data.get('Contributors')  # comma-separated or None

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_UpdateSong "
            "@ID          = ?, "
            "@Title       = ?, "
            "@Duration    = ?, "
            "@ReleaseDate = ?, "
            "@Genres      = ?, "
            "@Contributors= ?",
            song_id, title, duration, release_date,
            genres, contributors
        )
        conn.commit()
    except pyodbc.ProgrammingError:
        # If the stored proc raised “Song not found” or similar
        abort(404, description=f"Song with ID {song_id} not found")
    except pyodbc.Error as e:
        conn.rollback()
        abort(400, description=str(e))
    finally:
        conn.close()

    return get_song(song_id)


@songs_api.route('/<int:song_id>', methods=['DELETE'])
def delete_song(song_id):
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_DeleteSong @ID = ?",
            song_id
        )
        conn.commit()
    except pyodbc.ProgrammingError:
        abort(404, description=f"Song with ID {song_id} not found")
    finally:
        conn.close()

    # The triggers will automatically clean up any orphaned Collaborations, etc.
    return '', 204

@songs_api.route('/<int:song_id>/dependencies', methods=['GET'])
def get_song_dependencies(song_id):
    """
    GET /api/songs/{id}/dependencies
    Returns JSON with { CollaborationCount, ContributorCount } for this song.
    """
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_GetSongDependencies @SongID = ?",
            song_id
        )
        row = cursor.fetchone()
        if not row:
            # If the stored proc returned no rows, treat as zero dependencies
            return jsonify({"CollaborationCount": 0, "ContributorCount": 0}), 200

        return jsonify({
            "CollaborationCount": row.CollaborationCount,
            "ContributorCount":  row.ContributorCount
        }), 200

    except pyodbc.ProgrammingError as pe:
        # If the stored proc threw “does not exist” (song not found),
        # we map that to a 404
        # (Assumes sp_GetSongDependencies would throw if SongID is invalid)
        abort(404, description=f"Song with ID {song_id} not found")
    finally:
        conn.close()
