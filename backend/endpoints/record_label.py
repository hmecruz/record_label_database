from flask import Blueprint, request, jsonify, abort

record_label_api = Blueprint('record_label_api', __name__, url_prefix='/api/record_labels')

@record_label_api.route('', methods=['GET'])
def list_record_labels():
    """
    GET /api/record_labels
    Optional query params: name, location, website, email, phone
    Response: 200 OK, JSON list of record-label objects
    """
    # TODO: read filters from request.args, fetch matching rows from DB
    labels = []  # placeholder list of dicts
    return jsonify(labels), 200

@record_label_api.route('/<int:label_id>', methods=['GET'])
def get_record_label(label_id):
    """
    GET /api/record_labels/<id>
    Response: 200 OK with JSON object, or 404 if not found
    """
    # TODO: fetch single label by PK
    label = None  # replace with DB fetch
    if label is None:
        abort(404, description=f"RecordLabel with ID {label_id} not found")
    return jsonify(label), 200

@record_label_api.route('', methods=['POST'])
def create_record_label():
    """
    POST /api/record_labels
    Body (application/json): { Name, Location, Website, Email, PhoneNumber }
    Response: 201 Created with full object (including new RecordLabelID)
    """
    data = request.get_json() or {}
    # TODO: validate required fields, insert into DB, get new_id
    new_id = 0  # replace with actual identity value
    created = {
        "RecordLabelID": new_id,
        "Name": data.get("Name"),
        "Location": data.get("Location"),
        "Website": data.get("Website"),
        "Email": data.get("Email"),
        "PhoneNumber": data.get("PhoneNumber")
    }
    return jsonify(created), 201

@record_label_api.route('/<int:label_id>', methods=['PUT'])
def update_record_label(label_id):
    """
    PUT /api/record_labels/<id>
    Body (application/json): { Name, Location, Website, Email, PhoneNumber }
    Response: 200 OK with updated object, or 404 if not found
    """
    data = request.get_json() or {}
    # TODO: attempt update; if no rows affected, treat as not found
    updated = True  # replace with actual update result
    if not updated:
        abort(404, description=f"RecordLabel with ID {label_id} not found")
    result = {
        "RecordLabelID": label_id,
        "Name": data.get("Name"),
        "Location": data.get("Location"),
        "Website": data.get("Website"),
        "Email": data.get("Email"),
        "PhoneNumber": data.get("PhoneNumber")
    }
    return jsonify(result), 200

@record_label_api.route('/<int:label_id>', methods=['DELETE'])
def delete_record_label(label_id):
    """
    DELETE /api/record_labels/<id>
    Response: 204 No Content, or 404 if not found
    """
    # TODO: attempt delete; if no rows deleted, treat as not found
    deleted = True  # replace with actual delete result
    if not deleted:
        abort(404, description=f"RecordLabel with ID {label_id} not found")
    return '', 204
