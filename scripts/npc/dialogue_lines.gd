extends RefCounted
## What people say, by personality. Lines may use {name} (the heroine), {place}, {district}, {item}.

const GREET := {
	"cheerful": ["Oh, hi there! Lovely day, isn't it?", "Hey hey! You look like someone on a mission.", "Hi! Ooh, I like your style."],
	"shy": ["U-um... hello.", "Oh! S-sorry, I didn't see you there.", "...Hi."],
	"grumpy": ["What do you want?", "Make it quick, I'm busy.", "Hm. Yeah?"],
	"flirty": ["Well, hello. Haven't seen you around here before.", "Hey there, stranger~", "Oh? Did you come over just to talk to me?"],
	"calm": ["Good afternoon.", "Hello. Can I help you with something?", "Nice weather for a walk."],
	"thug": ["You lost, princess?", "Tch. What?", "This is our corner. Talk fast."],
}
const GREET_FRIEND := ["Oh, it's you, {name}! Good to see you again.", "Hey, {name}! Perfect timing.", "There she is! What's up, {name}?"]
const GREET_ENEMY := ["You again? Leave me alone.", "Stay away from me.", "...What now."]

const COMPLIMENT := {
	"cheerful": ["Aww, stop it! You just made my whole day!", "Hehe, thank you! You're pretty great yourself."],
	"shy": ["Eh?! M-me? ...Thank you.", "N-no way... but, um, thanks."],
	"grumpy": ["...Hmph. Well. Thanks, I guess.", "Flattery won't get you anywhere. ...But okay."],
	"flirty": ["I know~ But it sounds better coming from you.", "Careful, I might start liking you."],
	"calm": ["That's kind of you to say. Thank you.", "Thank you. I appreciate it."],
	"thug": ["...You messing with me? Heh. Fine.", "Tch. Nobody says that to me."],
}
const FLIRT_OK := {
	"cheerful": ["Hehe, you're bold! I kinda like that.", "Is this a date? Because it's going great."],
	"shy": ["W-wha— my face is burning...", "I... I wouldn't mind seeing you again."],
	"grumpy": ["...You're ridiculous. Don't stop.", "Hmph. Maybe you're not so bad."],
	"flirty": ["Oh, two can play that game~", "Smooth. Very smooth. Keep going."],
	"calm": ["My, my. You certainly know what to say.", "I'd like that. Let's get coffee sometime."],
	"thug": ["H-hey! Cut that out, people are watching!", "Don't... don't look at me like that."],
}
const FLIRT_NO := {
	"cheerful": ["Haha... let's maybe just be friends first?", "Whoa, slow down there!"],
	"shy": ["I-I don't... um... I have to go.", "Th-that's too much..."],
	"grumpy": ["Not interested.", "Try that again and I'm calling someone."],
	"flirty": ["Cute try. Not today though.", "Mm, I'll need more than that."],
	"calm": ["I think you've misread the situation.", "Let's keep this polite, shall we?"],
	"thug": ["Ha! In your dreams.", "Get lost before I get mad."],
}
const INSULT := {
	"cheerful": ["Wow... okay. That was mean.", "Why would you say that?!"],
	"shy": ["...", "S-sorry for existing, I guess..."],
	"grumpy": ["Same to you, pal.", "Get out of my face."],
	"flirty": ["Ugh, and I thought you were interesting.", "Rude. Bye."],
	"calm": ["I see. I'll be going then.", "There's no need for that."],
	"thug": ["What did you just say to me?!", "Oh, you're dead now."],
}
const TIP := [
	"Have you been to the {place}? It's over in {district}.",
	"If you need anything, the {place} in {district} is the place to go.",
	"My friend works near the {place}. It's in {district}, if you're curious.",
]
const SMALL_TALK := [
	"They say the trains will run all night during the summer festival.",
	"There's a cat that sleeps on the roof of the 24H Mart. Everyone feeds it.",
	"Watch the taxis around here, they drive like they're in a movie.",
	"I heard someone saw a girl fighting five guys in Kitano Heights last night. Wild, right?",
	"The cherry trees in the parks are blooming early this year.",
]
const HANDSHAKE := ["Nice to meet you!", "Good grip!", "Pleasure's mine.", "Heh, formal, aren't we?"]
const HANDSHAKE_NO := ["...No thanks.", "I'll pass.", "Don't touch me."]
const KISS_OK := ["!!! ...W-wow.", "Mm... that was nice.", "H-hey, in public?! ...Again?", "My heart's racing..."]
const KISS_NO := ["What do you think you're doing?!", "Pervert!", "Hands off!", "Excuse me?!"]
const LOST_ITEM := ["I dropped my {item} somewhere around here... could you help me look?", "Oh no, my {item}! It must have fallen out of my bag nearby..."]
const LOST_THANKS := ["My {item}! Thank you so much — please, take this!", "You found it! You're a lifesaver. Here, for your trouble."]
const DIRECTIONS := ["Excuse me... do you know which district the {place} is in?", "Sorry to bother you — I'm looking for the {place}. Which district is it in?"]
const DIRECTIONS_OK := ["That's right, thank you! Here, buy yourself a coffee.", "Perfect! Thanks a lot."]
const DIRECTIONS_NO := ["Hmm... I don't think that's right. I'll ask someone else.", "Are you sure? ...Never mind."]
const GOODBYE := ["See you around!", "Bye now.", "Take care.", "Later."]


static func pick(lines: Array, vars := {}) -> String:
	var line: String = lines[randi() % lines.size()]
	for key in vars:
		line = line.replace("{%s}" % key, str(vars[key]))
	return line


static func by(table: Dictionary, personality: String, vars := {}) -> String:
	return pick(table.get(personality, table["calm"]), vars)
