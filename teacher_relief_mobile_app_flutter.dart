/*
Teacher Relief Mobile App (Flutter) - Single-file demo (main.dart)

What's included:
- Sinhala UI for Teachers Relief management
- CRUD for Teachers, Timetable, Leaves
- Local persistence using shared_preferences (stores JSON)
- Simple auto-assignment algorithm (subject match + lowest workload)
- Export data as JSON (share/save)

How to run:
1. Create a new Flutter project (flutter create teacher_relief_app)
2. Replace lib/main.dart with this file's contents
3. Add dependency in pubspec.yaml:
   shared_preferences: ^2.0.20
   path_provider: ^2.0.14
   (optional) flutter_share or similar for sharing exported JSON
4. flutter pub get
5. flutter run (on Android/iOS emulator or device)

Notes:
- This is a demo single-file app for quick testing. For production split into files, add proper state management, validations, and backend integration.
- Strings are Sinhala, keep font that supports Sinhala for best rendering.
*/

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const TeacherReliefApp());
}

const String LS_TEACHERS = 'hr_teachers_v1';
const String LS_TIMETABLE = 'hr_timetable_v1';
const String LS_LEAVES = 'hr_leaves_v1';

class TeacherReliefApp extends StatelessWidget {
  const TeacherReliefApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ගුරුවරු Relief',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'NotoSans', // ensure Sinhala-supporting font added in pubspec if desired
      ),
      home: const HomePage(),
    );
  }
}

class Teacher {
  int id;
  String name;
  List<String> subjects;
  String contact;
  int workloadToday;

  Teacher({required this.id, required this.name, required this.subjects, required this.contact, this.workloadToday = 0});

  factory Teacher.fromJson(Map<String, dynamic> j) => Teacher(
    id: j['id'],
    name: j['name'],
    subjects: List<String>.from(j['subjects'] ?? []),
    contact: j['contact'] ?? '',
    workloadToday: j['workloadToday'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subjects': subjects,
    'contact': contact,
    'workloadToday': workloadToday,
  };
}

class TimetableRow {
  int id;
  String className;
  int period;
  int? teacherId;
  String subject;

  TimetableRow({required this.id, required this.className, required this.period, this.teacherId, required this.subject});

  factory TimetableRow.fromJson(Map<String, dynamic> j) => TimetableRow(
    id: j['id'],
    className: j['className'],
    period: j['period'],
    teacherId: j['teacherId'],
    subject: j['subject'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'className': className,
    'period': period,
    'teacherId': teacherId,
    'subject': subject,
  };
}

class LeaveRequest {
  int id;
  int teacherId;
  String date; // yyyy-mm-dd
  List<int> periods;
  String reason;
  String status; // pending / approved / rejected
  String createdAt;

  LeaveRequest({required this.id, required this.teacherId, required this.date, required this.periods, required this.reason, this.status='pending', required this.createdAt});

  factory LeaveRequest.fromJson(Map<String, dynamic> j) => LeaveRequest(
    id: j['id'],
    teacherId: j['teacherId'],
    date: j['date'],
    periods: List<int>.from(j['periods'] ?? []),
    reason: j['reason'] ?? '',
    status: j['status'] ?? 'pending',
    createdAt: j['createdAt'] ?? DateTime.now().toIso8601String(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'teacherId': teacherId,
    'date': date,
    'periods': periods,
    'reason': reason,
    'status': status,
    'createdAt': createdAt,
  };
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Teacher> teachers = [];
  List<TimetableRow> timetable = [];
  List<LeaveRequest> leaves = [];
  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final tRaw = prefs.getString(LS_TEACHERS);
    final ttRaw = prefs.getString(LS_TIMETABLE);
    final lRaw = prefs.getString(LS_LEAVES);

    setState((){
      teachers = tRaw != null ? List<Map<String,dynamic>>.from(jsonDecode(tRaw)).map((m)=>Teacher.fromJson(m)).toList() : [];
      timetable = ttRaw != null ? List<Map<String,dynamic>>.from(jsonDecode(ttRaw)).map((m)=>TimetableRow.fromJson(m)).toList() : [];
      leaves = lRaw != null ? List<Map<String,dynamic>>.from(jsonDecode(lRaw)).map((m)=>LeaveRequest.fromJson(m)).toList() : [];
    });
  }

  Future<void> saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(LS_TEACHERS, jsonEncode(teachers.map((t)=>t.toJson()).toList()));
    prefs.setString(LS_TIMETABLE, jsonEncode(timetable.map((r)=>r.toJson()).toList()));
    prefs.setString(LS_LEAVES, jsonEncode(leaves.map((l)=>l.toJson()).toList()));
  }

  void addTeacher(String name, String subjectsCsv, String contact) {
    final t = Teacher(id: DateTime.now().millisecondsSinceEpoch, name: name, subjects: subjectsCsv.split(',').map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList(), contact: contact);
    setState(()=> teachers.insert(0, t));
    logs.insert(0, '${DateTime.now()} - ගුරුවරු ${name} එකතු කරන ලදි');
    saveAll();
  }

  void deleteTeacher(int id) {
    setState(()=> teachers.removeWhere((t)=>t.id==id));
    // detach from timetable
    setState(()=> timetable = timetable.map((r){ if(r.teacherId==id) r.teacherId = null; return r; }).toList());
    logs.insert(0, '${DateTime.now()} - ගුරුවරු ID $id මකන ලදි');
    saveAll();
  }

  void addTimetableRow(String className, int period, int? teacherId, String subject) {
    final r = TimetableRow(id: DateTime.now().millisecondsSinceEpoch, className: className, period: period, teacherId: teacherId, subject: subject);
    setState(()=> timetable.insert(0, r));
    logs.insert(0, '${DateTime.now()} - කාලසටහනට පේළියක් එකතු කරන ලදි');
    saveAll();
  }

  void submitLeave(int teacherId, String date, List<int> periods, String reason) {
    final l = LeaveRequest(id: DateTime.now().millisecondsSinceEpoch, teacherId: teacherId, date: date, periods: periods, reason: reason, createdAt: DateTime.now().toIso8601String());
    setState(()=> leaves.insert(0, l));
    logs.insert(0, '${DateTime.now()} - ගුරුවරු ID $teacherId විසින් $date සඳහා නිවාඩු ඉල්ලීම යොමු කරන ලදි');
    saveAll();
  }

  // auto-assign per period
  Teacher? autoAssignTeacherForPeriod(int period, String subject) {
    final busyIds = timetable.where((t)=>t.period==period && t.teacherId!=null).map((t)=>t.teacherId!).toSet();
    final candidates = teachers.where((t)=>!busyIds.contains(t.id)).toList();
    var matched = candidates.where((t)=>t.subjects.contains(subject)).toList();
    if(matched.isEmpty) matched = candidates;
    matched.sort((a,b)=> (a.workloadToday).compareTo(b.workloadToday));
    return matched.isNotEmpty ? matched.first : null;
  }

  void approveLeave(int leaveId) {
    final leave = leaves.firstWhere((l)=>l.id==leaveId);
    for(final p in leave.periods) {
      final classRow = timetable.firstWhere((r)=> r.teacherId==leave.teacherId && r.period==p, orElse: ()=> TimetableRow(id:0,className:'Unknown',period:p,teacherId:null,subject:'General'));
      final subject = classRow.subject;
      final assigned = autoAssignTeacherForPeriod(p, subject);
      if(assigned != null) {
        setState(()=> assigned.workloadToday += 1);
        logs.insert(0, '${leave.date} - ${classRow.className} (Period $p) සඳහා ${assigned.name} පත් කරන ලදි');
      } else {
        logs.insert(0, '${leave.date} - ${classRow.className} (Period $p) සඳහා පත්කිරීම නොහැක');
      }
    }
    setState(()=> leaves = leaves.map((l)=> l.id==leaveId ? LeaveRequest(id:l.id, teacherId:l.teacherId, date:l.date, periods:l.periods, reason:l.reason, status:'approved', createdAt:l.createdAt) : l).toList());
    saveAll();
  }

  void rejectLeave(int leaveId) {
    setState(()=> leaves = leaves.map((l)=> l.id==leaveId ? LeaveRequest(id:l.id, teacherId:l.teacherId, date:l.date, periods:l.periods, reason:l.reason, status:'rejected', createdAt:l.createdAt) : l).toList());
    logs.insert(0, '${DateTime.now()} - නිවාඩු ඉල්ලීම ID $leaveId ප්‍රතික්ෂේප කරන ලදි');
    saveAll();
  }

  Future<void> exportData() async {
    final data = {
      'teachers': teachers.map((t)=>t.toJson()).toList(),
      'timetable': timetable.map((r)=>r.toJson()).toList(),
      'leaves': leaves.map((l)=>l.toJson()).toList(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/school-data-${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonStr);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Data exported: ${file.path}')));
  }

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [buildDashboard(), buildTeachersPage(), buildTimetablePage(), buildLeavesPage(), buildReportsPage()];
    return Scaffold(
      appBar: AppBar(title: const Text('ගුරුවරු Relief')),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i)=> setState(()=> _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'ඩැශ්බෝර්ඩ්'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'ගුරුවරුන්'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'කාලසටහන'),
          BottomNavigationBarItem(icon: Icon(Icons.request_page), label: 'නිවාඩු'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'සටහන්'),
        ],
      ),
      floatingActionButton: _selectedIndex == 1 ? FloatingActionButton(
        onPressed: ()=> showAddTeacherDialog(),
        child: const Icon(Icons.add),
      ) : _selectedIndex == 2 ? FloatingActionButton(
        onPressed: ()=> showAddTimetableDialog(),
        child: const Icon(Icons.add),
      ) : _selectedIndex == 3 ? FloatingActionButton(
        onPressed: ()=> showSubmitLeaveDialog(),
        child: const Icon(Icons.add),
      ) : FloatingActionButton(
        onPressed: ()=> exportData(),
        child: const Icon(Icons.download),
      ),
    );
  }

  Widget buildDashboard(){
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pending Leaves: ${leaves.where((l)=> l.status=='pending').length}', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('Total Teachers: ${teachers.length}', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 12),
          const Text('Logs:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SizedBox(height: 200, child: ListView.builder(itemCount: logs.length, itemBuilder: (c,i)=> ListTile(title: Text(logs[i])))),
        ],
      ),
    );
  }

  Widget buildTeachersPage(){
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: teachers.length,
      itemBuilder: (c,i){
        final t = teachers[i];
        return Card(
          child: ListTile(
            title: Text(t.name),
            subtitle: Text('විෂය: ${t.subjects.join(', ')}\nදුරකථන: ${t.contact} | අද වැඩ: ${t.workloadToday}'),
            trailing: IconButton(icon: const Icon(Icons.delete), onPressed: ()=> deleteTeacher(t.id)),
            isThreeLine: true,
          ),
        );
      }
    );
  }

  Widget buildTimetablePage(){
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: timetable.length,
      itemBuilder: (c,i){
        final r = timetable[i];
        final tname = r.teacherId != null ? (teachers.firstWhere((t)=> t.id==r.teacherId, orElse: ()=> Teacher(id:0,name:'Unknown',subjects:[],contact:'') ).name) : 'No teacher';
        return Card(
          child: ListTile(
            title: Text('${r.className} — ${r.subject} (Period ${r.period})'),
            subtitle: Text('ගුරුවරු: $tname'),
          ),
        );
      }
    );
  }

  Widget buildLeavesPage(){
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: leaves.length,
      itemBuilder: (c,i){
        final l = leaves[i];
        final tname = teachers.firstWhere((t)=> t.id==l.teacherId, orElse: ()=> Teacher(id:0,name:'Unknown',subjects:[],contact:'')).name;
        return Card(
          child: ListTile(
            title: Text('ID: ${l.id} — $tname'),
            subtitle: Text('දිනය: ${l.date} | වේලාවන්: ${l.periods.join(', ')} | තත්ත්වය: ${l.status}'),
            trailing: l.status=='pending' ? Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: ()=> approveLeave(l.id)),
              IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: ()=> rejectLeave(l.id)),
            ]) : null,
          ),
        );
      }
    );
  }

  Widget buildReportsPage(){
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Relief Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...teachers.map((t)=> Text('${t.name} — අදට පත්කළ Relief: ${t.workloadToday}')),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: ()=> exportData(), child: const Text('Export JSON')),
      ]),
    );
  }

  void showAddTeacherDialog(){
    final nameCtrl = TextEditingController();
    final subjCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx)=> AlertDialog(
      title: const Text('අළුත් ගුරුවරු එකතු කරන්න'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'නම')),
        TextField(controller: subjCtrl, decoration: const InputDecoration(labelText: 'විෂය (කොමාවෙන්)'),),
        TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'දුරකථන')),
      ],),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: (){ addTeacher(nameCtrl.text, subjCtrl.text, contactCtrl.text); Navigator.pop(ctx); }, child: const Text('Save')),
      ],
    ));
  }

  void showAddTimetableDialog(){
    final classCtrl = TextEditingController();
    final periodCtrl = TextEditingController(text: '1');
    int? selectedTeacherId;
    final subjectCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx)=> AlertDialog(
      title: const Text('කාලසටහනට පේළියක් එකතු කරන්න'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: classCtrl, decoration: const InputDecoration(labelText: 'පන්ති නාමය')),
        TextField(controller: periodCtrl, decoration: const InputDecoration(labelText: 'Period (සංඛ්‍යාව)'), keyboardType: TextInputType.number),
        DropdownButton<int?>(value: selectedTeacherId, hint: const Text('ගුරුවරු (optional)'), items: [
          const DropdownMenuItem<int?>(value: null, child: Text('-- none --')),
          ...teachers.map((t)=> DropdownMenuItem<int?>(value: t.id, child: Text(t.name)))
        ], onChanged: (v){ selectedTeacherId = v; setState((){}); }),
        TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'විෂය')),
      ])),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: (){ addTimetableRow(classCtrl.text, int.tryParse(periodCtrl.text) ?? 1, selectedTeacherId, subjectCtrl.text); Navigator.pop(ctx); }, child: const Text('Save')),
      ],
    ));
  }

  void showSubmitLeaveDialog(){
    int? selectedTeacherId = teachers.isNotEmpty ? teachers.first.id : null;
    final dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().substring(0,10));
    final periodsCtrl = TextEditingController(text: '1');
    final reasonCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx)=> AlertDialog(
      title: const Text('නිවාඩු ඉල්ලීම යොමු කරන්න'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButton<int?>(value: selectedTeacherId, items: teachers.map((t)=> DropdownMenuItem<int?>(value: t.id, child: Text(t.name))).toList(), onChanged: (v){ selectedTeacherId = v; setState((){}); }),
        TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'දිනය (YYYY-MM-DD)')),
        TextField(controller: periodsCtrl, decoration: const InputDecoration(labelText: 'Periods (comma separated)'),),
        TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'හේතුව')),
      ]),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: (){ if(selectedTeacherId!=null){ final periods = periodsCtrl.text.split(',').map((s)=> int.tryParse(s.trim()) ?? 1).toList(); submitLeave(selectedTeacherId!, dateCtrl.text, periods, reasonCtrl.text); Navigator.pop(ctx); } }, child: const Text('Submit')),
      ],
    ));
  }
}
