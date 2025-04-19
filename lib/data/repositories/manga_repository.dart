import 'package:dartz/dartz.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../datasources/api_service.dart';
import '../datasources/parser_service.dart';
import '../../core/errors/failures.dart';

class MangaRepository {
  final ApiService apiService;
  final ParserService parserService;

  MangaRepository({
    required this.apiService,
    required this.parserService,
  });

  Future<Either<Failure, List<Manga>>> getMangaList() async {
    try {
      final response = await apiService.getMangaList();
      final mangaList = parserService.parseMangaList(response);
      return Right(mangaList);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  Future<Either<Failure, List<Chapter>>> getChapters(String mangaId) async {
    try {
      final response = await apiService.getChapters(mangaId);
      final chapters = parserService.parseChapters(response);
      return Right(chapters);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
} 