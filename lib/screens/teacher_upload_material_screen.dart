import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/class_config.dart';
import '../models/study_material_model.dart';

class TeacherUploadMaterialScreen extends StatefulWidget {
  const TeacherUploadMaterialScreen({Key? key}) : super(key: key);

  @override
  State<TeacherUploadMaterialScreen> createState() => _TeacherUploadMaterialScreenState();
}

class _TeacherUploadMaterialScreenState extends State<TeacherUploadMaterialScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String _selectedClass = '11th';
  String _selectedSpecialization = 'Commerce';
  String _selectedSection = 'A';

  File? _selectedFile;
  String? _fileName;
  bool _isUploading = false;
  bool _isLoading = true;

  List<StudyMaterial> _materials = [];

  @override
  void initState() {
    super.initState();
    _fetchMyMaterials();
  }

  Future<void> _fetchMyMaterials() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getTeacherMaterials();
    if (mounted) {
      setState(() {
        _materials = data.map((e) => StudyMaterial.fromJson(e)).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final sizeInBytes = await file.length();
      final sizeInMb = sizeInBytes / (1024 * 1024);

      if (sizeInMb > 10.0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File is too large! Maximum allowed size is 10 MB.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _selectedFile = file;
        _fileName = result.files.single.name;
      });
    }
  }

  Future<void> _uploadMaterial() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please attach a file')));
      return;
    }

    setState(() => _isUploading = true);

    final combinedClass = ClassConfig.combineClassAndSpecialization(_selectedClass, _selectedSpecialization);

    final response = await ApiService.uploadStudyMaterial(
      title: title,
      description: _descController.text.trim(),
      className: combinedClass,
      section: _selectedSection,
      specialization: _selectedSpecialization.isNotEmpty ? _selectedSpecialization : null,
      filePath: _selectedFile!.path,
    );

    setState(() => _isUploading = false);

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material uploaded successfully!'), backgroundColor: Colors.green),
      );
      _titleController.clear();
      _descController.clear();
      setState(() {
        _selectedFile = null;
        _fileName = null;
      });
      _fetchMyMaterials(); // refresh list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload: ${response['message']}'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteMaterial(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Material?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('This will permanently delete the file.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      )
    );

    if (confirm != true) return;

    final response = await ApiService.deleteMaterial(id);
    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully')));
      _fetchMyMaterials();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${response['message']}')));
    }
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: items.map((T item) => DropdownMenuItem<T>(
                value: item,
                child: Text(item.toString(), style: GoogleFonts.poppins(fontSize: 14)),
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Study Notes', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Upload Form
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Notes Title *',
                    labelStyle: GoogleFonts.poppins(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    labelStyle: GoogleFonts.poppins(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown<String>(
                        label: 'Class',
                        value: _selectedClass,
                        items: ClassConfig.classes,
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _selectedClass = v;
                              final specs = ClassConfig.getSpecializationsForClass(v);
                              _selectedSpecialization = specs.isNotEmpty ? specs[0] : '';
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDropdown<String>(
                        label: 'Section',
                        value: _selectedSection,
                        items: ClassConfig.sections,
                        onChanged: (v) => setState(() => _selectedSection = v ?? 'A'),
                      ),
                    ),
                  ],
                ),
                if (ClassConfig.getSpecializationsForClass(_selectedClass).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDropdown<String>(
                    label: 'Specialization / Branch',
                    value: _selectedSpecialization,
                    items: ClassConfig.getSpecializationsForClass(_selectedClass),
                    onChanged: (v) => setState(() => _selectedSpecialization = v ?? ''),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: Text(_fileName ?? 'Select File', overflow: TextOverflow.ellipsis),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: Colors.teal.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isUploading ? null : _uploadMaterial,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      ),
                      child: _isUploading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Upload', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // List of previous uploads
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            alignment: Alignment.centerLeft,
            child: Text('Your Uploaded Notes', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
              : _materials.isEmpty
                ? Center(child: Text('No notes uploaded yet', style: GoogleFonts.poppins(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _materials.length,
                    itemBuilder: (context, index) {
                      final m = _materials[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            foregroundColor: Colors.teal.shade800,
                            child: const Icon(Icons.description),
                          ),
                          title: Text(m.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${m.className} - Sec ${m.section} ${m.specialization != null ? "(${m.specialization})" : ""}', style: TextStyle(color: Colors.teal.shade700, fontSize: 12)),
                              Text(m.fileName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.open_in_new, color: Colors.blue),
                                onPressed: () {
                                  launchUrl(Uri.parse('${ApiService.baseUrl}${m.fileUrl}'));
                                },
                                tooltip: 'View File',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteMaterial(m.id),
                                tooltip: 'Delete',
                              ),
                            ],
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
