from collections import OrderedDict
from distutils.version import StrictVersion

from babelapi.data_type import (
    Empty,
    doc_unwrap,
    is_composite_type,
    is_list_type,
)

class Api(object):
    """
    A full description of an API's namespaces, data types, and routes.
    """
    def __init__(self, version):
        self.version = StrictVersion(version)
        self.namespaces = OrderedDict()

    def ensure_namespace(self, name):
        """
        Only creates a namespace if it hasn't yet been defined.

        :param str name: Name of the namespace.

        :return ApiNamespace:
        """
        if name not in self.namespaces:
            self.namespaces[name] = ApiNamespace(name)
        return self.namespaces.get(name)

class ApiNamespace(object):
    """
    Represents a category of API endpoints and their associated data types.
    """

    def __init__(self, name):
        self.name = name
        self.routes = []
        self.route_by_name = {}
        self.data_types = []
        self.data_type_by_name = {}

    def add_route(self, route):
        self.routes.append(route)
        self.route_by_name[route.name] = route

    def add_data_type(self, data_type):
        self.data_types.append(data_type)
        self.data_type_by_name[data_type.name] = data_type

    def linearize_data_types(self):
        """
        Returns a list of all data types used in the namespace. Because the
        inheritance of data types can be modeled as a DAG, the list will be a
        linearization of the DAG. It's ideal to generate data types in this
        order so that composite types that reference other composite types are
        defined in the correct order.
        """
        linearized_data_types = []
        seen_data_types = set()

        found_empty = False
        for route in self.routes:
            for data_type in (route.request_data_type, route.response_data_type,
                              route.error_data_type):
                if data_type == Empty and not found_empty:
                    linearized_data_types.append(Empty)
                    seen_data_types.add(Empty)
                    found_empty = True
                    break

        def add_data_type(data_type):
            if data_type in seen_data_types:
                return
            if hasattr(data_type, 'supertype') and data_type.supertype:
                add_data_type(data_type.supertype)
            elif hasattr(data_type, 'subtype') and data_type.subtype:
                add_data_type(data_type.subtype)
            linearized_data_types.append(data_type)
            seen_data_types.add(data_type)

        for data_type in self.data_types:
            add_data_type(data_type)

        return linearized_data_types

    def distinct_route_io_data_types(self):
        """
        Returns all user-defined data types that are referenced as the request,
        response, or error data type for a route in this namespace.

        The List data type is never returned because it isn't user-defined, but
        if it contains a user-defined type, then that type is included in the
        return set.
        """
        data_types = set()
        for route in self.routes:
            for dtype in (route.request_data_type, route.response_data_type,
                          route.error_data_type):
                while is_list_type(dtype):
                    dtype = dtype.data_type
                if not is_composite_type(dtype):
                    continue
                data_types.add(dtype)
        return data_types

class ApiRoute(object):
    """
    Represents an API endpoint.
    """

    def __init__(self,
                 name,
                 doc,
                 request_data_type,
                 response_data_type,
                 error_data_type,
                 attrs,
                 token):
        """
        :param str name: Designated name of the endpoint.
        :param str doc: Description of the endpoint.
        :type request_data_type: :class:`babelapi.data_type.DataType`
        :type response_data_type: :class:`babelapi.data_type.DataType`
        :type error_data_type: :class:`babelapi.data_type.DataType`
        :param dict attrs: Map of string keys to values that are either int,
            float, bool, str, or None. These are the route attributes assigned
            in the spec.
        :param token: Raw route definition from the parser.
        :type token: babelapi.babel.parser.BabelRouteDef
        """

        self.name = name
        self.raw_doc = doc
        self.doc = doc_unwrap(doc)
        self.request_data_type = request_data_type
        self.response_data_type = response_data_type
        self.error_data_type = error_data_type
        self.attrs = attrs
        self._token = token
