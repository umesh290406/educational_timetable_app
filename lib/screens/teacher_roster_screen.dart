import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/student_roster_service.dart';
import '../widgets/loading_widget.dart';
import '../utils/class_config.dart';

class TeacherRosterScreen extends StatefulWidget {
  const TeacherRosterScreen({super.key});

  @override
  State<TeacherRosterScreen> createState() => _TeacherRosterScreenState();
}

class _TeacherRosterScreenState extends State<TeacherRosterScreen> {
  String _selectedClass = '11th';
  String _selectedSpecialization = 'Commerce';
  String _selectedSection = 'A';
  List<StudentProfile> _students = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    setState(() => _isLoading = true);
    final combinedClass = ClassConfig.combineClassAndSpecialization(_selectedClass, _selectedSpecialization);
    final students = await StudentRosterService.getStudentsForClass(combinedClass, _selectedSection);
    setState(() {
      _students = students;
      _isLoading = false;
    });
  }

  void _showAddEditStudentDialog({StudentProfile? existingStudent}) {
    final formKey = GlobalKey<FormState>();
    final rollController = TextEditingController(text: existingStudent?.rollNo);
    final nameController = TextEditingController(text: existingStudent?.name);
    final addressController = TextEditingController(text: existingStudent?.address);
    final contactController = TextEditingController(text: existingStudent?.contactNo);
    final parentsController = TextEditingController(text: existingStudent?.parentsNo);
    
    DateTime? selectedBirthday;
    if (existingStudent?.birthday != null && existingStudent!.birthday.isNotEmpty) {
      try {
        selectedBirthday = DateFormat('yyyy-MM-DD').parse(existingStudent.birthday);
      } catch (_) {}
    }

    final initialClassData = ClassConfig.parseClassAndSpecialization(existingStudent?.className ?? _selectedClass);
    String dialogClass = initialClassData['class'] ?? '11th';
    String dialogSpecialization = initialClassData['specialization'] ?? 'Commerce';
    String dialogSection = existingStudent?.section ?? _selectedSection;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final specializations = ClassConfig.getSpecializationsForClass(dialogClass);
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: theme.cardColor,
              title: Text(
                existingStudent == null ? 'Add Student Profile' : 'Edit Student Profile',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Form(
                  key: formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (existingStudent == null) ...[
                        // Class Select
                        Text('Class Name', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: dialogClass,
                              isExpanded: true,
                              items: ClassConfig.classes.map((cls) {
                                return DropdownMenuItem(
                                  value: cls,
                                  child: Text(cls, style: GoogleFonts.poppins(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    dialogClass = val;
                                    final newSpecs = ClassConfig.getSpecializationsForClass(val);
                                    dialogSpecialization = newSpecs.isNotEmpty ? newSpecs[0] : '';
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (specializations.isNotEmpty) ...[
                          Text('Specialization / Branch', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: dialogSpecialization,
                                isExpanded: true,
                                items: specializations.map((spec) {
                                  return DropdownMenuItem(
                                    value: spec,
                                    child: Text(spec, style: GoogleFonts.poppins(fontSize: 14)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      dialogSpecialization = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Section Select
                        Text('Section / Division', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: dialogSection,
                              isExpanded: true,
                              items: ClassConfig.sections.map((sec) {
                                return DropdownMenuItem(
                                  value: sec,
                                  child: Text('Section $sec', style: GoogleFonts.poppins(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    dialogSection = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Roll Number
                      TextFormField(
                        controller: rollController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(fontSize: 14),
                        enabled: existingStudent == null, // Roll number cannot be changed once created to avoid conflicts
                        decoration: InputDecoration(
                          labelText: 'Roll Number',
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter roll number';
                          if (int.tryParse(v) == null) return 'Enter a valid number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Name
                      TextFormField(
                        controller: nameController,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Student Name',
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter student name' : null,
                      ),
                      const SizedBox(height: 16),

                      // Birthday Date Picker
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        leading: Icon(Icons.cake, color: Colors.teal.shade600),
                        title: Text(
                          selectedBirthday == null ? 'Select Birthday' : DateFormat('yyyy-MM-dd').format(selectedBirthday!),
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedBirthday ?? DateTime(2005, 1, 1),
                            firstDate: DateTime(1995, 1, 1),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedBirthday = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Contact Number
                      TextFormField(
                        controller: contactController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Contact Number',
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter contact number';
                          if (v.length < 10) return 'Enter a valid phone number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Parents Contact
                      TextFormField(
                        controller: parentsController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Parents Contact Number',
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter parents contact';
                          if (v.length < 10) return 'Enter a valid phone number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Address
                      TextFormField(
                        controller: addressController,
                        maxLines: 2,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Home Address',
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter address' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    if (selectedBirthday == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select birthday date'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    final combinedClass = ClassConfig.combineClassAndSpecialization(dialogClass, dialogSpecialization);
                    final newProfile = StudentProfile(
                      rollNo: rollController.text.trim(),
                      name: nameController.text.trim(),
                      className: combinedClass,
                      section: dialogSection,
                      address: addressController.text.trim(),
                      contactNo: contactController.text.trim(),
                      parentsNo: parentsController.text.trim(),
                      birthday: DateFormat('yyyy-MM-dd').format(selectedBirthday!),
                    );

                    await StudentRosterService.saveStudent(newProfile);
                    Navigator.pop(context);
                    _loadRoster();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(existingStudent == null
                            ? 'Student added successfully!'
                            : 'Student profile updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: Text(
                    existingStudent == null ? 'Save' : 'Update',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade600,
        title: Text(
          'Student Roster',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditStudentDialog(),
        backgroundColor: Colors.teal.shade600,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Filter section
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.teal.shade600.withOpacity(0.08),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Class',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedClass,
                                isExpanded: true,
                                items: ClassConfig.classes.map((c) {
                                  return DropdownMenuItem(
                                    value: c,
                                    child: Text(c, style: GoogleFonts.poppins(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedClass = val;
                                      final specs = ClassConfig.getSpecializationsForClass(val);
                                      _selectedSpecialization = specs.isNotEmpty ? specs[0] : '';
                                    });
                                    _loadRoster();
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ClassConfig.getSpecializationsForClass(_selectedClass).isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Specialization',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedSpecialization,
                                  isExpanded: true,
                                  items: ClassConfig.getSpecializationsForClass(_selectedClass).map((spec) {
                                    return DropdownMenuItem(
                                      value: spec,
                                      child: Text(spec, style: GoogleFonts.poppins(fontSize: 13)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedSpecialization = val;
                                      });
                                      _loadRoster();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Section',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedSection,
                                isExpanded: true,
                                items: ClassConfig.sections.map((s) {
                                  return DropdownMenuItem(
                                    value: s,
                                    child: Text('Sec $s', style: GoogleFonts.poppins(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedSection = val);
                                    _loadRoster();
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const LoadingWidget(message: 'Loading student list...')
                : _students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No student profiles found',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap the "+" button to add profiles for this class.',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 24,
                            headingRowColor: MaterialStateProperty.all(Colors.teal.shade600.withOpacity(0.12)),
                            columns: [
                              DataColumn(label: Text('Sr. No', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.teal.shade800))),
                              DataColumn(label: Text('Roll No', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.teal.shade800))),
                              DataColumn(label: Text('Student Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.teal.shade800))),
                              DataColumn(label: Text('Birthday', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.teal.shade800))),
                              DataColumn(label: Text('Contact No', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.teal.shade800))),
                              DataColumn(label: Text('Parents Contact', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.teal.shade800))),
                              DataColumn(label: Text('Address', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.teal.shade800))),
                              DataColumn(label: Text('Actions', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.teal.shade800))),
                            ],
                            rows: List.generate(_students.length, (idx) {
                              final student = _students[idx];
                              return DataRow(
                                cells: [
                                  DataCell(Text((idx + 1).toString(), style: GoogleFonts.poppins(fontSize: 13))),
                                  DataCell(Text(student.rollNo, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold))),
                                  DataCell(Text(student.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold))),
                                  DataCell(Text(student.birthday, style: GoogleFonts.poppins(fontSize: 13))),
                                  DataCell(Text(student.contactNo, style: GoogleFonts.poppins(fontSize: 13))),
                                  DataCell(Text(student.parentsNo, style: GoogleFonts.poppins(fontSize: 13))),
                                  DataCell(Text(student.address, style: GoogleFonts.poppins(fontSize: 13))),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Colors.teal, size: 18),
                                          onPressed: () => _showAddEditStudentDialog(existingStudent: student),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Text('Delete Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                                content: Text('Are you sure you want to delete ${student.name}\'s profile?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, true),
                                                    child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await StudentRosterService.deleteStudent(
                                                className: student.className,
                                                section: student.section,
                                                rollNo: student.rollNo,
                                              );
                                              _loadRoster();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
