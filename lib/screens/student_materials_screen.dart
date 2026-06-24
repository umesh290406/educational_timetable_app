import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/study_material_model.dart';
import 'package:intl/intl.dart';

class StudentMaterialsScreen extends StatefulWidget {
  const StudentMaterialsScreen({Key? key}) : super(key: key);

  @override
  State<StudentMaterialsScreen> createState() => _StudentMaterialsScreenState();
}

class _StudentMaterialsScreenState extends State<StudentMaterialsScreen> {
  bool _isLoading = true;
  List<StudyMaterial> _materials = [];

  @override
  void initState() {
    super.initState();
    _fetchMaterials();
  }

  Future<void> _fetchMaterials() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null || user.className == null || user.section == null) {
      setState(() => _isLoading = false);
      return;
    }

    final data = await ApiService.getStudentMaterials(
      user.className!, 
      user.section!, 
      specialization: user.specialization
    );

    if (mounted) {
      setState(() {
        _materials = data.map((e) => StudyMaterial.fromJson(e)).toList();
        _isLoading = false;
      });
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('MMM d, yyyy • h:mm a').format(date);
    } catch (e) {
      return '';
    }
  }

  IconData _getFileIcon(String fileType, String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['doc', 'docx'].contains(ext)) return Icons.description;
    if (['ppt', 'pptx'].contains(ext)) return Icons.slideshow;
    if (['jpg', 'jpeg', 'png'].contains(ext)) return Icons.image;
    if (ext == 'zip') return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'pdf') return Colors.red;
    if (['doc', 'docx'].contains(ext)) return Colors.blue;
    if (['ppt', 'pptx'].contains(ext)) return Colors.orange;
    if (['jpg', 'jpeg', 'png'].contains(ext)) return Colors.green;
    return Colors.teal;
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      appBar: AppBar(
        title: Text('Study Materials', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.teal.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Notes Hub',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Showing materials for ${user?.className} • Section ${user?.section}${user?.specialization != null ? " • " + user!.specialization! : ""}',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.teal.shade700),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
              : _materials.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_off_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No study materials uploaded yet.', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _materials.length,
                    itemBuilder: (context, index) {
                      final m = _materials[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          onTap: () {
                            launchUrl(Uri.parse('${ApiService.baseUrl}${m.fileUrl}'));
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _getFileColor(m.fileName).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(_getFileIcon(m.fileType, m.fileName), size: 32, color: _getFileColor(m.fileName)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.title,
                                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      if (m.description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          m.description,
                                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text('Prof. ${m.teacherName}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text(_formatDate(m.createdAt), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.download_rounded, color: Colors.teal.shade600),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
