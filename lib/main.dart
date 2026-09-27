import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.init();
  runApp(const DeutschLernenApp());
}

class LocalStore {
  static late Database db;

  static const seed = <List<String>>[
    ['ich','أنا','Ich lerne Deutsch.'],['du','أنت','Du lernst Deutsch.'],['er','هو','Er wohnt in Berlin.'],
    ['sie','هي / هم','Sie kommt heute.'],['wir','نحن','Wir lernen zusammen.'],['ihr','أنتم','Ihr seid nett.'],
    ['sein','يكون','Ich möchte Arzt sein.'],['haben','يملك / لديه','Ich habe Zeit.'],['heißen','يُسمّى','Ich heiße Omar.'],
    ['wohnen','يسكن','Ich wohne in Fes.'],['lernen','يتعلم','Wir lernen Deutsch.'],['sprechen','يتحدث','Ich spreche Arabisch.'],
    ['machen','يفعل','Was machst du?'],['gehen','يذهب','Ich gehe nach Hause.'],['kommen','يأتي','Sie kommt morgen.'],
    ['essen','يأكل','Wir essen zusammen.'],['trinken','يشرب','Ich trinke Wasser.'],['lesen','يقرأ','Er liest ein Buch.'],
    ['schreiben','يكتب','Sie schreibt eine Nachricht.'],['sehen','يرى','Ich sehe einen Film.'],['hören','يسمع','Ich höre Musik.'],
    ['kaufen','يشتري','Wir kaufen Brot.'],['brauchen','يحتاج','Ich brauche Hilfe.'],['möchten','يرغب','Ich möchte Kaffee.'],
    ['können','يستطيع','Ich kann Deutsch sprechen.'],['müssen','يجب','Ich muss arbeiten.'],['gut','جيد','Das ist gut.'],
    ['schlecht','سيئ','Das Wetter ist schlecht.'],['groß','كبير','Das Haus ist groß.'],['klein','صغير','Der Hund ist klein.'],
    ['neu','جديد','Das Auto ist neu.'],['alt','قديم','Das Buch ist alt.'],['schnell','سريع','Der Zug ist schnell.'],
    ['langsam','بطيء','Bitte sprechen Sie langsam.'],['heute','اليوم','Heute lerne ich Deutsch.'],['morgen','غدًا','Bis morgen!'],
    ['gestern','أمس','Gestern war ich zu Hause.'],['jetzt','الآن','Ich komme jetzt.'],['immer','دائمًا','Ich lerne immer.'],
    ['oft','غالبًا','Ich lese oft.'],['Haus','منزل','Mein Haus ist klein.'],['Wohnung','شقة','Meine Wohnung ist schön.'],
    ['Zimmer','غرفة','Das Zimmer ist groß.'],['Tür','باب','Die Tür ist offen.'],['Fenster','نافذة','Das Fenster ist offen.'],
    ['Tisch','طاولة','Das Buch liegt auf dem Tisch.'],['Stuhl','كرسي','Der Stuhl ist bequem.'],['Buch','كتاب','Ich lese ein Buch.'],
    ['Schule','مدرسة','Die Schule beginnt um acht.'],['Arbeit','عمل','Ich gehe zur Arbeit.'],['Freund','صديق','Mein Freund kommt.'],
    ['Familie','عائلة','Meine Familie ist groß.'],['Mutter','أم','Meine Mutter kocht.'],['Vater','أب','Mein Vater arbeitet.'],
    ['Bruder','أخ','Mein Bruder ist jung.'],['Schwester','أخت','Meine Schwester lernt.'],['Kind','طفل','Das Kind spielt.'],
    ['Mann','رجل','Der Mann liest.'],['Frau','امرأة','Die Frau arbeitet.'],['Hund','كلب','Der Hund schläft.'],
    ['Katze','قطة','Die Katze trinkt Milch.'],['Wasser','ماء','Ich trinke Wasser.'],['Brot','خبز','Ich kaufe Brot.'],
    ['Milch','حليب','Die Milch ist kalt.'],['Kaffee','قهوة','Ich trinke Kaffee.'],['Tee','شاي','Möchtest du Tee?'],
    ['Apfel','تفاحة','Der Apfel ist rot.'],['Zeit','وقت','Ich habe keine Zeit.'],['Tag','يوم','Heute ist ein schöner Tag.'],
    ['Nacht','ليل','Gute Nacht!'],['Morgen','صباح','Guten Morgen!'],['Abend','مساء','Guten Abend!'],
    ['Hallo','مرحبًا','Hallo, wie geht es dir?'],['Danke','شكرًا','Danke für deine Hilfe.'],['bitte','من فضلك / عفوًا','Ein Wasser, bitte.'],
    ['ja','نعم','Ja, gern.'],['nein','لا','Nein, danke.'],['warum','لماذا','Warum lernst du Deutsch?'],
    ['was','ماذا','Was machst du?'],['wer','من','Wer ist das?'],['wo','أين','Wo wohnst du?'],
    ['wie','كيف','Wie heißt du?'],['wann','متى','Wann kommst du?'],['mit','مع','Ich komme mit dir.'],
    ['für','لـ / من أجل','Das ist für dich.'],['und','و','Deutsch und Arabisch.'],['aber','لكن','Ich bin müde, aber glücklich.'],
    ['oder','أو','Tee oder Kaffee?'],['nicht','لا / ليس','Ich verstehe das nicht.'],['sehr','جدًا','Das ist sehr gut.'],
    ['auch','أيضًا','Ich lerne auch Englisch.'],['richtig','صحيح','Das ist richtig.'],['falsch','خطأ','Die Antwort ist falsch.'],
    ['wichtig','مهم','Deutsch ist wichtig.'],['leicht','سهل','Die Aufgabe ist leicht.'],['schwer','صعب','Deutsch ist manchmal schwer.'],
    ['glücklich','سعيد','Ich bin glücklich.'],['müde','متعب','Ich bin müde.'],['hungrig','جائع','Ich bin hungrig.'],
    ['durstig','عطشان','Ich bin durstig.']
  ];

  static Future<void> init() async {
    final dir = await getDatabasesPath();
    db = await openDatabase(path.join(dir, 'deutsch_lernen.db'), version: 1,
      onCreate: (d, v) async {
        await d.execute('CREATE TABLE words (id INTEGER PRIMARY KEY AUTOINCREMENT, german TEXT NOT NULL, translation TEXT NOT NULL, example TEXT NOT NULL, builtin INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)');
        await d.execute('CREATE TABLE reviews (word_id INTEGER PRIMARY KEY, interval_days INTEGER NOT NULL DEFAULT 0, ease REAL NOT NULL DEFAULT 2.5, repetitions INTEGER NOT NULL DEFAULT 0, due_at TEXT)');
        await d.execute('CREATE INDEX words_german ON words(german)');
      });
    final n = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM words')) ?? 0;
    if (n == 0) {
      final batch = db.batch();
      final now = DateTime.now().toIso8601String();
      for (final w in seed) {
        batch.insert('words', {'german':w[0], 'translation':w[1], 'example':w[2], 'builtin':1, 'created_at':now});
      }
      await batch.commit(noResult:true);
    }
  }

  static Future<List<Map<String,Object?>>> words([String query='']) {
    final q=query.trim();
    return db.query('words',
      where:q.isEmpty ? null : 'german LIKE ? OR translation LIKE ?',
      whereArgs:q.isEmpty ? null : ['%'+q+'%','%'+q+'%'],
      orderBy:'german COLLATE NOCASE ASC', limit:500);
  }

  static Future<List<Map<String,Object?>>> due() {
    final now=DateTime.now().toIso8601String();
    return db.rawQuery('SELECT w.* FROM words w LEFT JOIN reviews r ON r.word_id=w.id WHERE r.word_id IS NULL OR r.due_at IS NULL OR r.due_at<=? ORDER BY COALESCE(r.due_at, "") ASC,w.id ASC LIMIT 30',[now]);
  }

  static Future<void> add(String german,String translation,String example) => db.insert('words',{
    'german':german.trim(),'translation':translation.trim(),'example':example.trim(),'builtin':0,'created_at':DateTime.now().toIso8601String()});

  static Future<void> remove(int id) async {
    await db.delete('reviews',where:'word_id=?',whereArgs:[id]);
    await db.delete('words',where:'id=?',whereArgs:[id]);
  }

  static Future<void> review(int id,bool remembered) async {
    final old=await db.query('reviews',where:'word_id=?',whereArgs:[id],limit:1);
    final m=old.isEmpty?null:old.first;
    final repetitions=(m?['repetitions'] as int? ?? 0);
    final ease=(m?['ease'] as num?)?.toDouble() ?? 2.5;
    final nextReps=remembered?repetitions+1:0;
    final previousInterval=m?['interval_days'] as int? ?? 30;
    final days=remembered?(nextReps==1?1:nextReps==2?3:nextReps==3?7:nextReps==4?14:nextReps==5?30:(previousInterval*ease).round().clamp(30,365).toInt()):0;
    final nextEase=remembered?(ease+0.05).clamp(1.3,3.0):(ease-0.15).clamp(1.3,3.0);
    await db.insert('reviews',{'word_id':id,'interval_days':days,'ease':nextEase,'repetitions':nextReps,
      'due_at':DateTime.now().add(remembered?Duration(days:days):const Duration(minutes:10)).toIso8601String()},
      conflictAlgorithm:ConflictAlgorithm.replace);
  }
}

class DeutschLernenApp extends StatelessWidget {
  const DeutschLernenApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,title:'Deutsch Lernen',
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF1565C0))),
    home:const HomeScreen());
}

class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState()=>_HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen> {
  Future<void> go(Widget page) async { await Navigator.push(context,MaterialPageRoute(builder:(_)=>page)); if(mounted)setState((){}); }
  Future<int> count() async => Sqflite.firstIntValue(await LocalStore.db.rawQuery('SELECT COUNT(*) FROM words'))??0;
  Future<int> dueCount() async { final now=DateTime.now().toIso8601String(); return Sqflite.firstIntValue(await LocalStore.db.rawQuery('SELECT COUNT(*) FROM words w LEFT JOIN reviews r ON r.word_id=w.id WHERE r.word_id IS NULL OR r.due_at IS NULL OR r.due_at<=?',[now]))??0; }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Deutsch Lernen'),centerTitle:true),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      Text('تعلم الألمانية بدون إنترنت',style:Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height:8),const Text('الكلمات والمراجعة والتمارين محفوظة بالكامل على الهاتف.'),
      const SizedBox(height:20),
      FutureBuilder(future:Future.wait([count(),dueCount()]),builder:(c,s){final v=s.data??[0,0];return Row(children:[
        Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[const Icon(Icons.menu_book),Text(v[0].toString(),style:Theme.of(context).textTheme.headlineMedium),const Text('كلمة')])))),
        const SizedBox(width:12),
        Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[const Icon(Icons.refresh),Text(v[1].toString(),style:Theme.of(context).textTheme.headlineMedium),const Text('للمراجعة')]))))]);}),
      const SizedBox(height:12),
      action('مراجعة الكلمات','بطاقات: كشف ثم سحب يمين/يسار',Icons.style,()=>go(const ReviewScreen())),
      action('قاموس الكلمات','بحث وتصفح وإضافة كلمات',Icons.search,()=>go(const LibraryScreen())),
      action('التمارين','اختر الترجمة الصحيحة',Icons.quiz,()=>go(const ExerciseScreen())),
      action('إضافة كلمة','أضف كلمة وترجمة ومثال',Icons.add_circle,()=>go(const AddWordScreen())),
    ]));
  Widget action(String title,String sub,IconData icon,VoidCallback tap)=>Card(child:ListTile(contentPadding:const EdgeInsets.all(12),leading:CircleAvatar(child:Icon(icon)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(sub),trailing:const Icon(Icons.chevron_right),onTap:tap));
}

class AddWordScreen extends StatefulWidget { const AddWordScreen({super.key}); @override State<AddWordScreen> createState()=>_AddWordState(); }
class _AddWordState extends State<AddWordScreen>{
  final german=TextEditingController(), translation=TextEditingController(), example=TextEditingController();
  @override void dispose(){german.dispose();translation.dispose();example.dispose();super.dispose();}
  Future<void> save() async {if(german.text.trim().isEmpty||translation.text.trim().isEmpty||example.text.trim().isEmpty)return;await LocalStore.add(german.text,translation.text,example.text);if(mounted)Navigator.pop(context);}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('إضافة كلمة')),body:ListView(padding:const EdgeInsets.all(20),children:[
    TextField(controller:german,textDirection:TextDirection.ltr,decoration:const InputDecoration(labelText:'الكلمة بالألمانية')),const SizedBox(height:12),
    TextField(controller:translation,decoration:const InputDecoration(labelText:'المعنى بالعربية')),const SizedBox(height:12),
    TextField(controller:example,textDirection:TextDirection.ltr,maxLines:3,decoration:const InputDecoration(labelText:'مثال بالألمانية')),const SizedBox(height:20),
    FilledButton(onPressed:save,child:const Text('حفظ محليًا'))]));
}

class LibraryScreen extends StatefulWidget { const LibraryScreen({super.key}); @override State<LibraryScreen> createState()=>_LibraryState(); }
class _LibraryState extends State<LibraryScreen>{
  final search=TextEditingController(); List<Map<String,Object?>> data=[];
  @override void initState(){super.initState();load();search.addListener(load);}
  @override void dispose(){search.removeListener(load);search.dispose();super.dispose();}
  Future<void> load()async{final x=await LocalStore.words(search.text);if(mounted)setState(()=>data=x);}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('قاموس الكلمات'),actions:[IconButton(onPressed:()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>const AddWordScreen()));load();},icon:const Icon(Icons.add))]),
    body:Column(children:[
      Padding(padding:const EdgeInsets.all(14),child:TextField(controller:search,decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'ابحث بالألمانية أو العربية'))),
      Expanded(child:ListView.builder(itemCount:data.length,itemBuilder:(context,index){final w=data[index];return Dismissible(
        key:ValueKey(w['id']),direction:DismissDirection.endToStart,onDismissed:(_)=>LocalStore.remove(w['id'] as int),
        background:Container(color:Colors.red,alignment:Alignment.centerRight,padding:const EdgeInsets.all(20),child:const Icon(Icons.delete,color:Colors.white)),
        child:ListTile(title:Text(w['german'] as String,textDirection:TextDirection.ltr,style:const TextStyle(fontWeight:FontWeight.bold)),
          subtitle:Text((w['translation'] as String)+'\n'+(w['example'] as String),textDirection:TextDirection.ltr),isThreeLine:true));}))
    ]));
}

class ReviewScreen extends StatefulWidget { const ReviewScreen({super.key}); @override State<ReviewScreen> createState()=>_ReviewState(); }
class _ReviewState extends State<ReviewScreen>{
  List<Map<String,Object?>> queue=[]; int index=0; bool revealed=false;
  @override void initState(){super.initState();load();}
  Future<void> load()async{queue=await LocalStore.due();if(mounted)setState((){});}
  Future<void> answer(bool remembered)async{await LocalStore.review(queue[index]['id'] as int,remembered);if(mounted)setState((){index++;revealed=false;});}
  Future<void> delete()async{await LocalStore.remove(queue[index]['id'] as int);queue.removeAt(index);if(index>=queue.length)index=queue.length-1;if(mounted)setState(()=>revealed=false);}
  @override Widget build(BuildContext context){
    if(queue.isEmpty||index<0||index>=queue.length)return Scaffold(appBar:AppBar(title:const Text('المراجعة')),body:const Center(child:Text('لا توجد كلمات مستحقة للمراجعة الآن.')));
    final w=queue[index];
    return Scaffold(appBar:AppBar(title:Text('مراجعة '+(index+1).toString()+'/'+queue.length.toString())),
      body:GestureDetector(
        onTap:()=>setState(()=>revealed=true),
        onHorizontalDragEnd:(d){final v=d.primaryVelocity??0;if(!revealed)setState(()=>revealed=true);else if(v>250)answer(true);else if(v<-250)answer(false);},
        onVerticalDragEnd:(d){if((d.primaryVelocity??0)>500)delete();},
        child:Padding(padding:const EdgeInsets.all(20),child:Card(child:Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Text(w['german'] as String,textDirection:TextDirection.ltr,style:Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight:FontWeight.bold)),
          const SizedBox(height:30),
          if(revealed)...[Text(w['translation'] as String,style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:15),
            Text(w['example'] as String,textDirection:TextDirection.ltr,textAlign:TextAlign.center),const SizedBox(height:30),
            Row(children:[Expanded(child:OutlinedButton(onPressed:()=>answer(false),child:const Text('لم أتذكر'))),const SizedBox(width:10),Expanded(child:FilledButton(onPressed:()=>answer(true),child:const Text('تذكرت')))])]
          else const Text('اضغط للكشف'),
          const SizedBox(height:20),const Text('يمين: تذكرت • يسار: لم أتذكر • أسفل: حذف',textAlign:TextAlign.center)
        ]))))));
  }
}

class ExerciseScreen extends StatefulWidget { const ExerciseScreen({super.key}); @override State<ExerciseScreen> createState()=>_ExerciseState(); }
class _ExerciseState extends State<ExerciseScreen>{
  List<Map<String,Object?>> words=[]; Map<String,Object?>? question; List<String> options=[]; String? selected; int score=0;
  @override void initState(){super.initState();start();}
  Future<void> start()async{words=await LocalStore.words();next();}
  void next(){if(words.length<4)return;words.shuffle();question=words.first;final set=<String>{question!['translation'] as String};while(set.length<4)set.add(words[set.length]['translation'] as String);options=set.toList()..shuffle();setState(()=>selected=null);}
  void choose(String option){if(selected!=null)return;setState((){selected=option;if(option==question!['translation'])score++;});}
  @override Widget build(BuildContext context){if(question==null)return const Scaffold(body:Center(child:CircularProgressIndicator()));final german=question!['german'] as String;return Scaffold(
    appBar:AppBar(title:Text('التمارين • النقاط '+score.toString())),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      const Text('اختر الترجمة الصحيحة',textAlign:TextAlign.center),const SizedBox(height:25),
      Card(child:Padding(padding:const EdgeInsets.all(30),child:Text(german,textDirection:TextDirection.ltr,textAlign:TextAlign.center,style:Theme.of(context).textTheme.displaySmall))),
      const SizedBox(height:20),
      ...options.map((option)=>Padding(padding:const EdgeInsets.only(bottom:10),child:OutlinedButton(onPressed:()=>choose(option),child:Padding(padding:const EdgeInsets.all(12),child:Text(option,textAlign:TextAlign.center))))),
      if(selected!=null)...[const SizedBox(height:10),Text(selected==question!['translation']?'إجابة صحيحة ✓':'الإجابة الصحيحة: '+(question!['translation'] as String),textAlign:TextAlign.center),const SizedBox(height:10),FilledButton(onPressed:next,child:const Text('السؤال التالي'))]
    ]));}
}
