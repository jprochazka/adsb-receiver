import logging

from flask import abort, Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from flask_restx import Namespace, Resource, fields as restx_fields
from marshmallow import Schema, fields, ValidationError
from backend.models import db, Link
from backend.auth import require_user_or_admin
from werkzeug.exceptions import HTTPException
from sqlalchemy import select

links = Blueprint('links', __name__)

# Create Flask-RESTX namespaces for links management
links_ns = Namespace('links', description='Links list operations')
link_ns = Namespace('link', description='Individual link operations')

# Define API models for documentation
link_model = link_ns.model('Link', {
    'id': restx_fields.Integer(description='Link ID'),
    'name': restx_fields.String(description='Link name'),
    'address': restx_fields.String(description='Link URL address')
})

create_link_model = link_ns.model('CreateLink', {
    'name': restx_fields.String(required=True, description='Link name', example='FlightAware'),
    'address': restx_fields.String(required=True, description='Link URL address', example='https://flightaware.com')
})

update_link_model = link_ns.model('UpdateLink', {
    'name': restx_fields.String(required=True, description='Updated link name'),
    'address': restx_fields.String(required=True, description='Updated link URL address')
})

links_list_model = links_ns.model('LinksList', {
    'links': restx_fields.List(restx_fields.Nested(link_model)),
    'offset': restx_fields.Integer(description='Pagination offset'),
    'limit': restx_fields.Integer(description='Pagination limit'),
    'count': restx_fields.Integer(description='Number of links returned')
})


class CreateLinkRequestSchema(Schema):
    name = fields.String(required=True)
    address = fields.String(required=True)

class UpdateLinkRequestSchema(Schema):
    name = fields.String(required=True)
    address = fields.String(required=True)
        

@link_ns.route('')
class LinksResource(Resource):
    @link_ns.expect(create_link_model)
    @link_ns.response(201, 'Link created successfully')
    @link_ns.response(400, 'Bad request - validation error')
    @link_ns.response(401, 'Unauthorized - authentication required')
    @link_ns.response(500, 'Internal server error')
    @link_ns.doc('create_link', security='Bearer')
    @require_user_or_admin()
    def post(self):
        """Create a new link (Authentication required)"""
        try:
            payload = CreateLinkRequestSchema().load(request.json)
        except ValidationError as err:
            return {'msg': 'Validation error', 'errors': err.messages}, 400

        try:
            new_link = Link(
                name=payload['name'],
                address=payload['address']
            )
            db.session.add(new_link)
            db.session.commit()
            return {'msg': 'Link created successfully'}, 201
        except Exception as ex:
            db.session.rollback()
            logging.error(f"Error encountered while trying to post link", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@link_ns.route('/<int:link_id>')
class LinkResource(Resource):
    @link_ns.marshal_with(link_model, code=200)
    @link_ns.response(404, 'Link not found')
    @link_ns.response(401, 'Unauthorized - authentication required')
    @link_ns.response(500, 'Internal server error')
    @link_ns.doc('get_link', security='Bearer')
    @require_user_or_admin()
    def get(self, link_id):
        """Get link by ID (Authentication required)"""
        try:
            link = db.session.get(Link, link_id)
            
            if not link:
                return {'msg': 'Link not found'}, 404
                
            return link.to_dict(), 200
        except Exception as ex:
            logging.error(f"Error encountered while trying to get link id {link_id}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    @link_ns.expect(update_link_model)
    @link_ns.response(204, 'Link updated successfully')
    @link_ns.response(400, 'Bad request - validation error')
    @link_ns.response(404, 'Link not found')
    @link_ns.response(401, 'Unauthorized - authentication required')
    @link_ns.response(500, 'Internal server error')
    @link_ns.doc('update_link', security='Bearer')
    @require_user_or_admin()
    def put(self, link_id):
        """Update link by ID (Authentication required)"""
        try:
            payload = UpdateLinkRequestSchema().load(request.json)
        except ValidationError as err:
            return {'msg': 'Validation error', 'errors': err.messages}, 400

        try:
            link = db.session.get(Link, link_id)
            
            if not link:
                return {'msg': 'Link not found'}, 404
                
            link.name = payload['name']
            link.address = payload['address']
            
            db.session.commit()
            return {'msg': 'Link updated successfully'}, 204
        except Exception as ex:
            db.session.rollback()
            logging.error(f"Error encountered while trying to put link id {link_id}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    @link_ns.response(204, 'Link deleted successfully')
    @link_ns.response(404, 'Link not found')
    @link_ns.response(401, 'Unauthorized - authentication required')
    @link_ns.response(500, 'Internal server error')
    @link_ns.doc('delete_link', security='Bearer')
    @require_user_or_admin()
    def delete(self, link_id):
        """Delete link by ID (Authentication required)"""
        try:
            link = db.session.get(Link, link_id)
            
            if not link:
                return {'msg': 'Link not found'}, 404
                
            db.session.delete(link)
            db.session.commit()
            return {'msg': 'Link deleted successfully'}, 204
        except Exception as ex:
            db.session.rollback()
            logging.error(f"Error encountered while trying to delete link id {link_id}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@links_ns.route('')
class LinksListResource(Resource):
    @links_ns.marshal_with(links_list_model, code=200)
    @links_ns.response(400, 'Bad request - invalid offset or limit parameters')
    @links_ns.response(500, 'Internal server error')
    @links_ns.doc('get_links_list', params={
        'offset': 'Pagination offset (default: 0)',
        'limit': 'Number of links to return (default: 50, max: 100)'
    })
    def get(self):
        """Get list of links with pagination"""
        offset = request.args.get('offset', default=0, type=int)
        limit = request.args.get('limit', default=50, type=int)
        
        if offset < 0 or limit < 1 or limit > 100:
            return {'msg': 'Bad Request - invalid offset or limit parameters'}, 400
            
        try:
            links_result = db.session.execute(
                select(Link)
                .order_by(Link.name)
                .offset(offset)
                .limit(limit)
            )
            links_data = [link.to_dict() for link in links_result.scalars()]
            
            return {
                'offset': offset,
                'limit': limit,
                'count': len(links_data),
                'links': links_data
            }, 200
        except Exception as ex:
            logging.error('Error encountered while trying to get links', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


