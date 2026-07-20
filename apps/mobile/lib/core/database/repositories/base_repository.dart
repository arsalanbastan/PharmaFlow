import '../database_service.dart';

abstract class BaseRepository {
  BaseRepository();

  DatabaseService get database => DatabaseService.instance;
}