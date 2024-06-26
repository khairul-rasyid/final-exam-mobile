import 'package:flutter/material.dart';
import 'package:flutter_application/services/notif.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_application/pages/add_task.dart';
import 'package:flutter_application/services/dbservices.dart';
import 'package:flutter_application/pages/detail_task.dart';
import 'package:intl/intl.dart';

class TaskPage extends StatefulWidget {
  final User? user;
  const TaskPage({super.key, this.user});

  @override
  // ignore: library_private_types_in_public_api
  _TaskPageState createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  late DateTime _selectedDay;
  late CalendarFormat _calendarFormat;
  late Map<DateTime, List<dynamic>> _events;
  // ignore: unused_field
  late List<dynamic> _selectedEvents;

  late User userData;
  final TextEditingController _searchTask = TextEditingController();

  @override
  void initState() {
    _searchTask.addListener(onSearchTask);
    userData = widget.user!;
    super.initState();
    _selectedDay = DateTime.now();
    _calendarFormat = CalendarFormat.week;
    _events = {};
    _selectedEvents = [];
  }

  Stream<QuerySnapshot<Object?>> onSearchTask() {
    setState(() {});
    return Database.getData(
        userUid: userData.uid,
        field: 'status',
        condition: 'on going',
        title: _searchTask.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 75),
        child: FloatingActionButton(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddTask(user: userData)),
            );
          },
          backgroundColor: const Color(0xff5B67CA),
          child: const Icon(
            Icons.add,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Widget untuk menampilkan search
              CupertinoSearchTextField(
                controller: _searchTask,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: const Icon(Icons.clear),
                borderRadius: const BorderRadius.all(Radius.circular(15)),
                itemSize: 30.0,
                backgroundColor: const Color(0xFFF6F6F6),
                padding: const EdgeInsetsDirectional.fromSTEB(10, 15, 10, 15),
              ),
              const SizedBox(height: 10),
              // Widget untuk menampilkan kalender
              _buildTableCalendar(),
              const SizedBox(height: 18),
              // Widget untuk menampilkan hari dan waktu
              _buildDayAndTime(),
              // Widget untuk menampilkan tugas
              StreamBuilder<QuerySnapshot>(
                stream: onSearchTask(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text("ERROR");
                  } else if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.blue),
                      ),
                    );
                  } else if (snapshot.hasData || snapshot.data != null) {
                    return ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        DocumentSnapshot clData = snapshot.data!.docs[index];
                        DateTime utc8 =
                            (clData['datetime'] as Timestamp).toDate();
                        DateTime dateTime =
                            utc8.subtract(const Duration(hours: 8));
                        DateTime localTime = dateTime.toLocal();

                        String dtTitle = clData['title'];
                        String dtDate =
                            DateFormat('dd MMMM yyyy').format(localTime);
                        String dtTime = DateFormat('HH:mm').format(localTime);
                        String dtDesc = clData['desc'];
                        String dtTags = clData['tags'];
                        int dtIdNotif = clData['idNotif'];
                        return Dismissible(
                          key: Key('$dtIdNotif'),
                          confirmDismiss: (direction) =>
                              _deleteTaskDialog(context),
                          onDismissed: (direction) {
                            Notif.cancelScheduledNotif(dtIdNotif);
                            Database.deleteData(docsName: dtTitle);
                          },
                          background: Container(
                            color: Colors.white,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: const Icon(Icons.delete, color: Colors.red),
                          ),
                          secondaryBackground: Container(
                            color: Colors.white,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: const Icon(Icons.delete, color: Colors.red),
                          ),
                          child: _buildTask(
                            // index: index,
                            title: dtTitle,
                            date: dtDate,
                            time: dtTime,
                            desc: dtDesc,
                            tags: dtTags,
                            idNotif: dtIdNotif,
                          ),
                        );
                      },
                      itemCount: snapshot.data!.docs.length,
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(500),
                    child: Center(
                      child: Text("No Task"),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget untuk menampilkan kalender
  Widget _buildTableCalendar() {
    return TableCalendar(
      focusedDay: _selectedDay,
      firstDay: DateTime.utc(2021, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      calendarFormat: _calendarFormat,
      availableCalendarFormats: const {
        CalendarFormat.week: 'Week',
      },
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _selectedEvents = _events[_selectedDay] ?? [];
        });
      },
      eventLoader: (day) {
        return _events[day] ?? [];
      },
    );
  }

  // Widget untuk menampilkan hari dan waktu
  Widget _buildDayAndTime() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Task',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Text(
        //   '09 h 45 min',
        //   style: TextStyle(fontSize: 18),
        // ),
      ],
    );
  }

  // Widget untuk menampilkan setiap tugas
  Widget _buildTask({
    required String title,
    required String date,
    required String time,
    required String desc,
    required String tags,
    required int idNotif,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => DetailTask(
                      title: title,
                      date: date,
                      time: time,
                      desc: desc,
                      tags: tags,
                      idNotif: idNotif,
                    )),
          );
        },
        tileColor: _tileColor(tags: tags),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        leading: _icon(tags: tags),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF000000),
            fontWeight: FontWeight.w500,
          ),
        ),
        titleTextStyle: const TextStyle(fontSize: 20),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(
              children: [
                Text(date.toString()),
                const SizedBox(
                  width: 10,
                ),
                Text(time.toString())
              ],
            ),
            const SizedBox(height: 8),
            _tags(tagsName: tags),
          ],
        ),
      ),
    );
  }

  Color _tileColor({required String tags}) {
    if (tags == "personal") {
      return const Color(0xFF858FE9).withOpacity(0.18);
    } else if (tags == "work") {
      return const Color(0xFF7FC9E7).withOpacity(0.18);
    } else if (tags == "private") {
      return const Color(0xFFE77D7D).withOpacity(0.18);
    } else if (tags == "meeting") {
      return const Color(0xFF81E89E).withOpacity(0.18);
    } else if (tags == "events") {
      return const Color(0xFF858FE9).withOpacity(0.18);
    }
    return const Color(0xFFFFFFFF);
  }

  Widget _icon({required String tags}) {
    if (tags == "personal") {
      return _styleIcon(
          nameIcon: Icons.person_outline_rounded,
          color: const Color(0xFF858FE9));
    } else if (tags == "work") {
      return _styleIcon(
          nameIcon: Icons.work_outline_rounded, color: const Color(0xff7FC9E7));
    } else if (tags == "private") {
      return _styleIcon(
          nameIcon: Icons.lock_outline_rounded, color: const Color(0xFFE77D7D));
    } else if (tags == "meeting") {
      return _styleIcon(
          nameIcon: Icons.meeting_room_outlined,
          color: const Color(0xFF81E89E));
    } else if (tags == "events") {
      return _styleIcon(
          nameIcon: Icons.calendar_month, color: const Color(0xFF858FE9));
    }
    return const Text("E");
  }

  Widget _styleIcon({required IconData nameIcon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        nameIcon,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  Widget _tags({required String tagsName}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      decoration: BoxDecoration(
        color: _tileColor(tags: tagsName).withOpacity(1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tagsName,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
        ),
      ),
    );
  }

  Future<bool> _deleteTaskDialog(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Center(
              child: Text(
            'Delete Task',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          )),
          content: const Text(
            'Are you sure to delete this task?',
            style: TextStyle(fontSize: 18),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'No',
                style: TextStyle(fontSize: 18),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Yes',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        );
      },
    );
  }
}
