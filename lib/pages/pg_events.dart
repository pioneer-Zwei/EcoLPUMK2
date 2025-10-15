import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../config/eco_styles.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final List<Map<String, dynamic>> glownaListaWydarzen = [
    {
      "type": "eco", "title": "Campus Beautification Society", "subject": "Let us convene to discuss the planting of new rose bushes near the main library.", "body": "The Society's autumn meeting will finalise the bulb-planting schedule for the coming months. We have received a generous donation of tulip and daffodil bulbs, and discussion will centre on the most aesthetically pleasing arrangement for the flowerbeds flanking the main entrance. Tea and biscuits will be provided. All who appreciate a vibrant campus are encouraged to contribute their ideas.", "user": "Head Prefect", "avatar": "HP", "timestamp": "October 14, 1916 - 3:00 PM", "joinable": true,
    },
    {
      "type": "jutland", "title": "Naval Engagement Reported", "subject": "First reports indicate a major naval battle in the North Sea.", "body": "Unconfirmed wireless intercepts suggest that Admiral Beatty's Battlecruiser Fleet has made contact with Admiral Hipper's scouting group. The initial exchange of fire is reported to be at extreme range. The full strength of the Grand Fleet under Admiral Jellicoe is still several hours away, steaming south from Scapa Flow. The fate of the North Sea hangs in the balance.", "user": "War Correspondent", "avatar": "WC", "timestamp": "May 31, 1916 - 16:30", "joinable": false,
    },
    {
      "type": "eco", "title": "Scholarly Debate on Industrial Smog", "subject": "The Dialectic Society will host a debate on the effects of industrial smog on public health.", "body": "The proposition, 'That the unchecked industrial emissions pose a greater long-term threat to the Empire than any foreign power,' will be argued by Mr. Alistair Finch of the Natural Philosophy Society. The opposition will be led by Mr. Reginald Thorne from the Engineering Faculty. The Dean of Sciences will moderate. A lively and informative evening is anticipated.", "user": "Debate Club", "avatar": "DC", "timestamp": "October 15, 1916 - 7:00 PM", "joinable": true,
    },
    {
      "type": "jutland", "title": "Great Push on the Somme", "subject": "Field Marshal Haig reports a major offensive has commenced on the Western Front.", "body": "In what appears to be the largest Allied offensive of the war to date, British and French forces have launched a coordinated attack against German lines along the River Somme. The initial artillery bombardment was of unprecedented scale. The hope is that this push will relieve the pressure on the French at Verdun and achieve a decisive breakthrough. Heavy casualties are expected on both sides.", "user": "War Office", "avatar": "WO", "timestamp": "July 1, 1916 - Communiqué", "joinable": false,
    },
    {
      "type": "eco", "title": "A Plea for Silence", "subject": "The Head Librarian reminds all students that the library is a place for silent study.", "body": "It has come to my attention that levels of chatter, particularly in the history stacks, have risen to an unacceptable level. The library is a sanctuary for scholarship, not a common room for socializing. Henceforth, any student found talking above a whisper will be asked to leave. Let us maintain a peaceful environment conducive to learning.", "user": "Head Librarian", "avatar": "HL", "timestamp": "October 12, 1916 - Notice", "joinable": false,
    },
    {
      "type": "jutland", "title": "HMS Indefatigable Lost", "subject": "Grave news. It is believed HMS Indefatigable has been sunk following a tremendous explosion.", "body": "Eyewitness accounts from the nearby HMS New Zealand describe a catastrophic series of explosions in the 'X' magazine of the Indefatigable. The ship was observed to capsize and sink in a matter of minutes, leaving few survivors. This is a devastating blow to the Battlecruiser Fleet early in the engagement.", "user": "Naval Command", "avatar": "NC", "timestamp": "May 31, 1916 - 17:02", "joinable": false,
    },
    {
      "type": "eco", "title": "For Sale: 'Principles of Aether Physics'", "subject": "A lightly used copy of Prof. Harrington's 'Principles of Aether Physics' is available.", "body": "The textbook is essential for any first-year student of the Natural Sciences. My copy has minimal annotations in the margins, which may prove more helpful than a hindrance. I am asking a fair price. Please find me in the student common room after dinner should you wish to purchase it.", "user": "Arthur P.", "avatar": "AP", "timestamp": "October 16, 1916 - 4:30 PM", "joinable": false,
    },
    {
      "type": "eco", "title": "Gas Lamp Curfew", "subject": "A reminder that all gas lamps in student residences must be extinguished by 10 o'clock sharp.", "body": "To conserve the university's fuel reserves for the winter and to contribute to the national conservation effort, the Proctor's office will be enforcing a strict 10 o'clock curfew for all gas lighting in dormitories. Students requiring light for late-night study should make use of the main library, which remains open until 11 o'clock.", "user": "The Proctor", "avatar": "P", "timestamp": "October 17, 1916 - Announcement", "joinable": false,
    },
    {
      "type": "jutland", "title": "Romania Enters the War", "subject": "Bucharest has declared war on Austria-Hungary, joining the Allied cause.", "body": "After much diplomatic maneuvering, the Kingdom of Romania has committed its forces to the Entente. Romanian troops are reportedly crossing the Carpathian mountains into Transylvania. This opens a new front and will place additional strain on the Central Powers, though the Romanian army's readiness for a modern war remains to be seen.", "user": "Reuters Dispatch", "avatar": "RD", "timestamp": "August 28, 1916 - Report", "joinable": false,
    },
    {
      "type": "eco", "title": "Notice: Paper Conservation Drive", "subject": "A university-wide drive to conserve paper is underway. Please use both sides of your notebooks.", "body": "In light of national shortages and as a matter of general thrift, the Bursar's office reminds all students and faculty to be judicious in their use of paper. Before requesting new notebooks, ensure your current ones are completely filled. Writing smaller is encouraged. Every page saved is a contribution to the university's efficiency.", "user": "The Bursar", "avatar": "B", "timestamp": "October 13, 1916 - 9:00 AM", "joinable": false,
    },
    {
      "type": "jutland", "title": "Rebellion in Dublin Suppressed", "subject": "Official sources confirm the surrender of nationalist rebels in Ireland.", "body": "The so-called 'Easter Rising' has been brought to an end after several days of fierce fighting in Dublin. The leaders of the insurrection have surrendered and are now in custody. While order has been restored, the General Post Office and other key buildings in the city have been heavily damaged. The government has declared martial law in the city.", "user": "The London Gazette", "avatar": "LG", "timestamp": "April 30, 1916 - Official Report", "joinable": false,
    },
    {
      "type": "jutland", "title": "5th Battle Squadron Engaged", "subject": "Admiral Evan-Thomas's powerful battleships are now in the fray.", "body": "The 5th Battle Squadron, consisting of the fast battleships Barham, Valiant, Warspite, and Malaya, has finally caught up to the action. Their 15-inch guns are a formidable addition to Beatty's force, but they are now facing the combined firepower of Hipper's battlecruisers and the main German battle fleet. Reports indicate HMS Malaya has sustained damage.", "user": "Naval Gazette", "avatar": "NG", "timestamp": "May 31, 1916 - 17:45", "joinable": false,
    },
    {
      "type": "eco", "title": "Poetry Society Reading", "subject": "An informal reading of verse will take place in the west common room.", "body": "All are welcome to join an evening of poetic expression. Attendees may bring a piece to share—either their own work or a favourite from the masters—or simply come to listen. We will focus on themes of Autumn and reflection. Light refreshments will be available.", "user": "Poetry Society", "avatar": "PS", "timestamp": "October 26, 1916 - 8:00 PM", "joinable": true,
    },
    {
      "type": "eco", "title": "Conker Collection Drive!", "subject": "Collect horse-chestnuts for the war effort! Prizes for the heaviest collection.", "body": "The Ministry of Munitions has issued a call for schoolchildren and students to collect 'conkers'. The chestnuts are needed for the production of acetone, a vital component in the manufacture of cordite for shells and bullets. A collection point has been set up by the main gate. Let's show our support for the lads at the front!", "user": "Student War Council", "avatar": "SWC", "timestamp": "October 11, 1916 - Initiative", "joinable": false,
    },
    {
      "type": "jutland", "title": "HMS Invincible Lost", "subject": "A third battlecruiser, HMS Invincible, has been destroyed.", "body": "Reports confirm the loss of Admiral Hood's flagship, HMS Invincible. During a fierce exchange with the German battlecruisers Lützow and Derfflinger, a shell is believed to have penetrated 'Q' turret, igniting the cordite within and causing a magazine explosion that split the ship in two. The loss of life is tragically immense.", "user": "Admiralty", "avatar": "AD", "timestamp": "May 31, 1916 - 19:33", "joinable": false,
    },
    {
      "type": "eco", "title": "Lost: 'A Treatise on Light'", "subject": "I have misplaced my copy of James Clerk Maxwell's 'A Treatise on the Theory of Light'.", "body": "It is a heavy, blue-bound volume and is absolutely essential for my upcoming examinations. I believe I may have left it in the physics laboratory or perhaps the main reading room of the library. If found, I would be eternally grateful for its return. Please leave a note with the porter.", "user": "Thomas K.", "avatar": "TK", "timestamp": "October 28, 1916 - 1:00 PM", "joinable": false,
    },
    {
      "type": "jutland", "title": "Russian Steamroller Advances", "subject": "Reports from the Eastern Front indicate a massive and successful Russian offensive.", "body": "General Brusilov has launched a surprisingly powerful offensive in Galicia, catching the Austro-Hungarian forces completely by surprise. Early reports speak of widespread collapse and the capture of tens of thousands of prisoners. This action should significantly relieve the pressure on our Italian allies and force Germany to divert troops from the Western Front.", "user": "Reuters Dispatch", "avatar": "RD", "timestamp": "June 10, 1916 - Report", "joinable": false,
    },
    {
      "type": "eco", "title": "Seeking assistance with Latin Prose", "subject": "Is anyone proficient in translating Cicero? I am finding this week's assignment particularly troublesome.", "body": "The specific passage from 'De Officiis' is proving a challenge. I would be most grateful to convene with a fellow classicist for an hour or two in the library to compare our translations and unravel some of the more complex clauses. I can offer a cup of tea in exchange for your scholarly assistance.", "user": "Beatrice H.", "avatar": "BH", "timestamp": "October 24, 1916 - 10:00 AM", "joinable": true,
    },
    {
      "type": "eco", "title": "Victory Garden Initiative", "subject": "Volunteers are needed to help tend the university's new vegetable gardens.", "body": "To aid the national effort, a portion of the west lawn has been converted to vegetable patches. We require diligent students to assist with weeding, watering, and eventually harvesting. No prior experience is necessary. This is a fine opportunity to get fresh air and contribute to the university's self-sufficiency.", "user": "The Dean's Office", "avatar": "DO", "timestamp": "October 20, 1916 - Announcement", "joinable": true,
    },
    {
      "type": "eco", "title": "Chess Club Tournament", "subject": "The annual university chess tournament begins next week. All skill levels are welcome.", "body": "Sharpen your wits and prepare your gambits! The knockout tournament to determine the university's chess champion is upon us. A sign-up sheet has been posted in the games room. Even if you do not wish to compete, spectators are most welcome to observe the matches.", "user": "Chess Club", "avatar": "CC", "timestamp": "November 1, 1916 - 2:00 PM", "joinable": true,
    },
    {
      "type": "jutland", "title": "Grand Fleet Deploys", "subject": "Admiral Jellicoe has successfully deployed the Grand Fleet, crossing the German 'T'.", "body": "In a manoeuvre of immense complexity and skill, Admiral Jellicoe has positioned the Grand Fleet's battle line directly across the path of the advancing German High Seas Fleet. This allows the full broadside weight of the British dreadnoughts to be brought to bear, while the German ships can only reply with their forward guns. A decisive moment in the battle is at hand.", "user": "On-Scene Observer", "avatar": "OSO", "timestamp": "May 31, 1916 - 19:17", "joinable": false,
    },
    {
      "type": "eco", "title": "Drama Society Auditions", "subject": "Auditions will be held for this term's production, Oscar Wilde's 'The Importance of Being Earnest'.", "body": "We are seeking talented thespians to fill all major roles. Auditions will consist of a cold reading from the script. Those interested in stage management or set design are also encouraged to attend. Let us provide a welcome distraction for the university community in these serious times. The sign-up sheet is posted outside the refectory.", "user": "Drama Society", "avatar": "DS", "timestamp": "October 29, 1916 - 6:00 PM", "joinable": true,
    },
    {
      "type": "jutland", "title": "HMHS Britannic Sunk", "subject": "The sister ship of the Titanic, serving as a hospital ship, has been lost in the Aegean.", "body": "The White Star liner HMHS Britannic has sunk, reportedly after striking a German mine. The vessel was in the process of evacuating wounded soldiers from the Gallipoli campaign. Fortunately, due to the ship's proximity to land and the rapid response of rescue vessels, the loss of life is reported to be minimal. This is the largest ship lost in the war to date.", "user": "The Times", "avatar": "T", "timestamp": "November 21, 1916 - Report", "joinable": false,
    },
    {
      "type": "jutland", "title": "Stalemate at Verdun", "subject": "The German offensive against the French fortress-city of Verdun has ground to a halt.", "body": "After months of the most horrific fighting imaginable, the German assault on Verdun has culminated in a bloody stalemate. French forces under General Pétain have held the line with heroic determination, summed up by the national cry, 'They shall not pass!' The cost in lives on both sides is staggering, and the battle has become a grim symbol of attritional warfare.", "user": "French Press Agency", "avatar": "FPA", "timestamp": "August 1, 1916 - Summary", "joinable": false,
    },
    {
      "type": "eco", "title": "Photographic Society Competition", "subject": "Announcing the first annual 'Autumnal Scenes' photography competition.", "body": "The University Photographic Society invites all amateur photographers to submit their best work capturing the beauty of the season on campus. Submissions will be judged on composition and clarity. The winning photograph will be displayed in the main hall. Entries must be submitted by the end of the month.", "user": "Photo Club", "avatar": "PC", "timestamp": "October 18, 1916 - 12:00 PM", "joinable": false,
    },
    {
      "type": "jutland", "title": "President Wilson Secures Re-election", "subject": "News from America indicates a narrow victory for the incumbent President.", "body": "President Woodrow Wilson has won a second term in the White House, running on a platform of neutrality and peace under the slogan 'He Kept Us Out of War.' His opponent, Charles Evans Hughes, was favoured by those who advocate for a more interventionist stance. The election result suggests that the American public is not yet ready to enter the European conflict.", "user": "American Correspondent", "avatar": "AC", "timestamp": "November 8, 1916 - Dispatch", "joinable": false,
    },
    {
      "type": "jutland", "title": "The 'Mad Monk's' Influence Grows", "subject": "Whispers from Petrograd speak of Grigori Rasputin's increasing sway over the Russian court.", "body": "Reports smuggled out of Russia suggest that the mystic Grigori Rasputin now holds an almost unbreakable influence over Tsarina Alexandra, and through her, the Tsar himself. With the Tsar at the front, Rasputin's meddling in state affairs and ministerial appointments is causing widespread alarm among the Russian aristocracy and political classes.", "user": "Foreign Office", "avatar": "FO", "timestamp": "November 15, 1916 - Intelligence", "joinable": false,
    },
    {
      "type": "jutland", "title": "Arab Revolt in the Desert", "subject": "Arab tribes have risen up against Ottoman rule in the Hejaz region.", "body": "Led by Sherif Hussein bin Ali of Mecca, Arab forces have successfully attacked the Turkish garrisons at Mecca and Jeddah. This revolt, supported by British advisors including a young officer named T.E. Lawrence, aims to create a unified independent Arab state and could prove to be a major distraction for the Ottoman Empire, diverting troops from other fronts.", "user": "Cairo Press Bureau", "avatar": "CPB", "timestamp": "June 12, 1916 - Report", "joinable": false,
    },
    {
      "type": "jutland", "title": "Conflicting Victory Claims", "subject": "Both London and Berlin are claiming victory in the recent naval battle.", "body": "The Admiralty has declared a strategic victory, emphasizing that the German fleet fled the field and the naval blockade of Germany remains unbroken. Meanwhile, German newspapers are celebrating a tactical triumph, citing the greater number of British ships and sailors lost. The truth of the matter will likely be debated by naval historians for years to come.", "user": "The Daily Telegraph", "avatar": "DT", "timestamp": "June 5, 1916 - Morning Edition", "joinable": false,
    },
    {
      "type": "jutland", "title": "Fleets Return to Port", "subject": "The battle appears concluded. Both fleets are now steaming for their respective home ports.", "body": "Though the German High Seas Fleet has retired to Wilhelmshaven, the cost to the Royal Navy has been severe, with the loss of three battlecruisers and three armoured cruisers. The Admiralty has not yet released an official statement, but claims of victory from both sides are beginning to circulate. The full strategic outcome of this colossal engagement remains unclear.", "user": "The Times", "avatar": "T", "timestamp": "June 2, 1916 - 09:00", "joinable": false,
    }
  ];

  late List<Map<String, dynamic>> filtrowaneWydarzenia;
  final DateFormat formatDaty = DateFormat('MMMM d, yyyy - h:mm a');

  @override
  void initState() {
    super.initState();
    generujFiltrowanyKanal();
  }

  void generujFiltrowanyKanal() {
    final random = Random();
    filtrowaneWydarzenia = glownaListaWydarzen.where((event) {
      if (event['type'] == 'jutland') {
        return random.nextDouble() < 0.25;
      }
      return true;
    }).map((event) {
      return {...event, 'isJoined': false, 'isExpanded': false};
    }).toList();
    filtrowaneWydarzenia.shuffle(random);
  }

  void dodajWydarzenie(String title, String subject, String body, bool isScheduled, String? timestamp) {
    setState(() {
      filtrowaneWydarzenia.insert(0, {
        "type": "eco",
        "title": title,
        "subject": subject,
        "body": body,
        "user": "You",
        "avatar": "Y",
        "timestamp": timestamp ?? formatDaty.format(DateTime.now()),
        "joinable": isScheduled,
        "isJoined": isScheduled,
        "isExpanded": true,
      });
    });
  }

  Future<DateTime?> wybierzDateICzas(BuildContext context, DateTime initialDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !context.mounted) return null;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (pickedTime == null) return null;

    return DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
  }

  void pokazDialogDodawaniaWydarzenia() {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    final bodyController = TextEditingController();
    DateTime selectedDateTime = DateTime.now().add(const Duration(hours: 1));
    bool isScheduled = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Share an Update'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Post"),
                        Switch(
                          value: isScheduled,
                          onChanged: (value) => setDialogState(() => isScheduled = value),
                          activeThumbColor: AppTheme.primaryRed,
                        ),
                        const Text("Scheduled Event"),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                    TextField(controller: subjectController, decoration: const InputDecoration(labelText: 'Subject')),
                    TextField(controller: bodyController, decoration: const InputDecoration(labelText: 'Body'), maxLines: 4),
                    if (isScheduled)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: OutlinedButton.icon(
                          icon: const Icon(LucideIcons.calendar),
                          label: Text(DateFormat('MMM d, yyyy - h:mm a').format(selectedDateTime)),
                          onPressed: () async {
                            final picked = await wybierzDateICzas(context, selectedDateTime);
                            if (picked != null) {
                              setDialogState(() => selectedDateTime = picked);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty && subjectController.text.isNotEmpty) {
                      final timestamp = isScheduled ? formatDaty.format(selectedDateTime) : null;
                      dodajWydarzenie(titleController.text, subjectController.text, bodyController.text, isScheduled, timestamp);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
                  child: const Text('Share', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget zbudujDolnyPasekNawigacji() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: AppTheme.cardBg,
      elevation: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          przyciskNawigacyjny(LucideIcons.house, 'Home', '/home'),
          przyciskNawigacyjny(LucideIcons.scanLine, 'Classifier', '/scanner'),
          const SizedBox(width: 48),
          przyciskNawigacyjny(LucideIcons.trendingUp, 'Tracker', '/trackImpact'),
          przyciskNawigacyjny(LucideIcons.user, 'Profile', '/profile'),
        ],
      ),
    );
  }

  Widget przyciskNawigacyjny(IconData icon, String tooltip, String route) {
    return IconButton(
      icon: Icon(icon, color: AppTheme.lightText, size: 26),
      tooltip: tooltip,
      onPressed: () => Navigator.pushReplacementNamed(context, route),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: AppTheme.primaryRed, shape: BoxShape.circle),
            child: const Icon(LucideIcons.calendar, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Campus Chronicle', style: AppTheme.headline2),
            Text('Events and University Notices', style: AppTheme.subtitle),
          ]),
        ]),
      ),
      bottomNavigationBar: zbudujDolnyPasekNawigacji(),
      floatingActionButton: FloatingActionButton(
        onPressed: pokazDialogDodawaniaWydarzenia,
        backgroundColor: AppTheme.primaryRed,
        shape: const CircleBorder(),
        tooltip: 'New Post',
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: filtrowaneWydarzenia.length,
        itemBuilder: (context, index) {
          return EventCard(
            key: ValueKey(filtrowaneWydarzenia[index]['title']! + filtrowaneWydarzenia[index]['timestamp']!),
            event: filtrowaneWydarzenia[index],
          );
        },
      ),
    );
  }
}

class EventCard extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventCard({super.key, required this.event});

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  late bool isExpanded;
  late bool isJoined;

  @override
  void initState() {
    super.initState();
    isExpanded = widget.event['isExpanded'];
    isJoined = widget.event['isJoined'];
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isJutland = event['type'] == 'jutland';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 3))
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => isExpanded = !isExpanded),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(
                    backgroundColor: isJutland ? Colors.blueGrey.shade700 : AppTheme.primaryRed,
                    child: Text(event['avatar']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(event['title']!, style: AppTheme.headline1.copyWith(fontSize: 18)),
                      Text('Posted by ${event['user']!}', style: AppTheme.bodyText.copyWith(fontSize: 12, color: Colors.black54)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(event['subject']!, style: AppTheme.bodyText),
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  Text(event['body']!, style: AppTheme.bodyText.copyWith(color: Colors.black.withValues(alpha: 0.7))),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1, color: Colors.black12),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(event['timestamp']!, style: AppTheme.subtitle.copyWith(fontSize: 12)),
                    if (event['joinable'])
                      ElevatedButton.icon(
                        onPressed: () => setState(() => isJoined = !isJoined),
                        icon: Icon(isJoined ? Icons.check : Icons.add, size: 16),
                        label: Text(isJoined ? 'Joined' : 'Join'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isJoined ? Colors.grey : AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}