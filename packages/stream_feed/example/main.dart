import 'dart:io';

import 'package:stream_feed/stream_feed.dart';

Future<void> main() async {
  final env = Platform.environment;
  final secret = env['secret'];
  final apiKey = env['apiKey'];
  var clientWithSecret =
      StreamClient.connect(apiKey!, secret: secret); //Token(token!)
  final chris = clientWithSecret.flatFeed('user', 'chris');

// Add an Activity; message is a custom field - tip: you can add unlimited custom fields!
  final addedPicture = await chris.addActivity(Activity(
      actor: 'chris',
      verb: 'add',
      object: 'picture:10',
      foreignId: 'picture:10',
      extraData: {'message': 'Beautiful bird!'}));

// Create a following relationship between Jack's "timeline" feed and Chris' "user" feed:
  final jack = clientWithSecret.flatFeed('timeline', 'jack');
  await jack.follow(chris);

// Read Jack's timeline and Chris' post appears in the feed:
  final results = await jack.getActivities(limit: 10);

// Remove an Activity by referencing it's Foreign Id:
  await chris.removeActivityByForeignId('picture:10');

  // Instantiate a feed using feed group 'user' and user id '1'
  final user1 = clientWithSecret.flatFeed('user', '1');

// Create an activity object
  var activity = Activity(actor: 'User:1', verb: 'pin', object: 'Place:42');

// Add an activity to the feed
  final pinActivity = await user1.addActivity(activity);
  print('HEY ${pinActivity.id}');

// Create a bit more complex activity
  activity =
      Activity(actor: 'User:1', verb: 'run', object: 'Exercise:42', extraData: {
    'course': const {'name': 'Golden Gate park', 'distance': 10},
    'participants': const ['Thierry', 'Tommaso'],
    'started_at': DateTime.now().toIso8601String(),
    'foreign_id': 'run:1',
    'location': const {
      'type': 'point',
      'coordinates': [37.769722, -122.476944]
    }
  });

  final exercise = await user1.addActivity(activity);

  // Get 5 activities with id less than the given UUID (Faster - Recommended!)
  var response = await user1.getActivities(
      limit: 5,
      filter: Filter().idLessThan("e561de8f-00f1-11e4-b400-0cc47a024be0"));
// Get activities from 5 to 10 (Pagination-based - Slower)
  response = await user1.getActivities(offset: 0, limit: 5);
// Get activities sorted by rank (Ranked Feeds Enabled):
  // response = await userFeed.getActivities(limit: 5, ranking: "popularity");//must be enabled

  // Remove an activity by its id
  await user1.removeActivityById(addedPicture.id!);

// Remove activities foreign_id 'run:1'
  await user1.removeActivityByForeignId('run:1');

  // partial update by activity ID
  // await user1.updateActivityById(ActivityUpdate(id:pinActivity.id!, set:{
  //   // 'product.price': 19.99,
  //   'shares': {'facebook': '...', 'twitter': '...'},
  // }));

// partial update by foreign ID
// client.activityPartialUpdate({
//   foreign_id: 'product:123',
//   time: '2016-11-10T13:20:00.000000',
//   set: {
//     ...
//   },
//   unset: [
//     ...
//   ]
// })

//Batching Partial Updates TODO
  final now = DateTime.now();
  final first_activity = Activity(
    actor: '1',
    verb: 'add',
    object: '1',
    foreignId: 'activity_1',
    time: DateTime.now(),
  );

// Add activity to activity feed:
  final firstActivityAdded = await user1.addActivity(first_activity);

  final second_activity = Activity(
      actor: '1', verb: 'add', object: '1', foreignId: 'activity_2', time: now);

  final secondActivityAdded = await user1.addActivity(second_activity);

  //Following Feeds
  // timeline:timeline_feed_1 follows user:user_42:
  final timelineFeed1 =
      clientWithSecret.flatFeed('timeline', 'timeline_feed_1');
  final user42feed = clientWithSecret.flatFeed('user', 'user_42');
  await timelineFeed1.follow(user42feed);

// Follow feed without copying the activities:
  await timelineFeed1.follow(user42feed, activityCopyLimit: 0);

  //Unfollowing feeds
  // Stop following feed user_42 - purging history:
  await timelineFeed1.unfollow(user42feed);

// Stop following feed user_42 but keep history of activities:
  await timelineFeed1.unfollow(user42feed, keepHistory: true);

//Reading Feed Followers
  // List followers
  await user1.followers(limit: 10, offset: 10);

  // get follower and following stats of the feed
  await clientWithSecret.flatFeed('user', 'me').followStats();

// get follower and following stats of the feed but also filter with given slugs
// count by how many timelines follow me
// count by how many markets are followed
  await clientWithSecret
      .flatFeed('user', 'me')
      .followStats(followerSlugs: ['timeline'], followingSlugs: ['market']);
//Realtime
  final frontendToken = clientWithSecret.frontendToken('john-doe');

//Use Case: Mentions
  // Add the activity to Eric's feed and to Jessica's notification feed
  activity = Activity(
    actor: 'user:Eric',
    extraData: {
      'message': "@Jessica check out getstream.io it's awesome!",
    },
    verb: 'tweet',
    object: 'tweet:id',
    to: [FeedId.id('notification:Jessica')],
  );

  await user1.addActivity(activity);
//Adding Collections
  // await client.collections.add(
  //   'food',
  //   {'name': 'Cheese Burger', 'rating': '4 stars'},
  //   entryId: 'cheese-burger',
  // );//will throw an error if entry-id already exists

// if you don't have an id on your side, just use null as the ID and Stream will generate a unique ID
  final entry = await clientWithSecret.collections
      .add('food', {'name': 'Cheese Burger', 'rating': '4 stars'});
  await clientWithSecret.collections.get('food', entry.id!);
  await clientWithSecret.collections.update(
      entry.copyWith(data: {'name': 'Cheese Burger', 'rating': '1 star'}));
  await clientWithSecret.collections.delete('food', entry.id!);

  // first we add our object to the food collection
  final cheeseBurger = await clientWithSecret.collections.add('food', {
    'name': 'Cheese Burger',
    'ingredients': ['cheese', 'burger', 'bread', 'lettuce', 'tomato'],
  });

// the object returned by .add can be embedded directly inside of an activity
  await user1.addActivity(Activity(
    actor: clientWithSecret.currentUser!.ref,
    verb: 'grill',
    object: cheeseBurger.ref,
  ));

// if we now read the feed, the activity we just added will include the entire full object
  await user1.getEnrichedActivities();

// we can then update the object and Stream will propagate the change to all activities
  await clientWithSecret.collections.update(cheeseBurger.copyWith(data: {
    'name': 'Amazing Cheese Burger',
    'ingredients': ['cheese', 'burger', 'bread', 'lettuce', 'tomato'],
  }));

  // First create a collection entry with upsert api
  await clientWithSecret.collections.upsert('food', [
    CollectionEntry(id: 'cheese-burger', data: {'name': 'Cheese Burger'}),
  ]);

// Then create a user
  await clientWithSecret.user('john-doe').getOrCreate({
    'name': 'John Doe',
    'occupation': 'Software Engineer',
    'gender': 'male',
  });

// Since we know their IDs we can create references to both without reading from APIs
  final cheeseBurgerRef =
      clientWithSecret.collections.entry('food', 'cheese-burger').ref;
  final johnDoeRef = clientWithSecret.user('john-doe').ref;

// And then add an activity with these references
  await clientWithSecret.flatFeed('user', 'john').addActivity(Activity(
        actor: johnDoeRef,
        verb: 'eat',
        object: cheeseBurgerRef,
      ));

  final client = StreamClient.connect(apiKey, token: frontendToken);
// ensure the user data is stored on Stream
  await client.setUserData({
    'name': 'John Doe',
    'occupation': 'Software Engineer',
    'gender': 'male'
  });

  // create a new user, if the user already exist an error is returned
  // await client.user('john-doe').create({
  //   'name': 'John Doe',
  //   'occupation': 'Software Engineer',
  //   'gender': 'male'
  // });

// get or create a new user, if the user already exist the user is returned
  await client.user('john-doe').getOrCreate({
    'name': 'John Doe',
    'occupation': 'Software Engineer',
    'gender': 'male'
  });

//retrieving users
  await client.user('john-doe').get();

  await client.user('john-doe').update({
    'name': 'Jane Doe',
    'occupation': 'Software Engineer',
    'gender': 'female'
  });

  //removing users
  await client.user('john-doe').delete();

  // Read the personalized feed for a given user
  var params = {'user_id': 'john-doe', 'feed_slug': 'timeline'};

  clientWithSecret.personalization.get('personalized_feed', params: params);

//Our data science team will typically tell you which endpoint to use
  params = {
    'user_id': 'john-doe',
    'source_feed_slug': 'timeline',
    'target_feed_slug': 'user'
  };

  // await client.personalization
  //     .get('discovery_feed', params: params);
}
