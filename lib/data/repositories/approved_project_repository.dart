import '../../core/database/database_helper.dart';
import '../../domain/models/approved_project.dart';

class ApprovedProjectRepository {
  Future<List<ApprovedProject>> getAllProjects() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('approved_projects', orderBy: 'id DESC');
    return maps.map((m) => ApprovedProject.fromMap(m)).toList();
  }

  Future<List<ApprovedProject>> getProjectsByClient(int clientId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'approved_projects',
      where: 'client_id = ?',
      whereArgs: [clientId],
      orderBy: 'id DESC',
    );
    return maps.map((m) => ApprovedProject.fromMap(m)).toList();
  }

  Future<int> insertProject(ApprovedProject project) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('approved_projects', project.toMap());
  }

  Future<int> updateProject(ApprovedProject project) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'approved_projects',
      project.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  /// Deletes a project. Linked invoices keep their rows but their
  /// `project_id` is nulled (FK ON DELETE SET NULL) so no invoice data lost.
  Future<int> deleteProject(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('approved_projects', where: 'id = ?', whereArgs: [id]);
  }
}
