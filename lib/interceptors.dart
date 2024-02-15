import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class CacheInterceptor extends Interceptor{
  @override
  Future onResponse(Response response, ResponseInterceptorHandler handler) async {
    if (response.statusCode == 200 && response.requestOptions.method == 'GET') {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/station_cache.json');
        await file.writeAsString(jsonEncode(response.data));
      } catch (e) {
        print('Error caching response: $e');
      }
    }
    return super.onResponse(response, handler);
  }

  @override
  Future onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.requestOptions.method == 'POST' &&
        err.error is SocketException) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/post_request_cache.json');
        await file.writeAsString(jsonEncode({
          'url': err.requestOptions.uri.toString(),
          'data': err.requestOptions.data,
        }));
      } catch (e) {
        print('Error caching post request: $e');
      }
    }
    return super.onError(err, handler);
  }
}