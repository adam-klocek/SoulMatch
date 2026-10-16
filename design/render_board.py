"""Rebuild the illustrative mobile design reference (not browser screenshots)."""
from pathlib import Path
import base64, html, math
root=Path(__file__).resolve().parents[1]
portrait=base64.b64encode((root/'www/assets/demo-portraits.png').read_bytes()).decode()
P={'teal':'#364F4B','coral':'#D58B80','peach':'#E9B8A5','ivory':'#F4EDE6','lavender':'#B59AC6','paper':'#FFFCF8','muted':'#5F6C65','line':'#DEDCD3','lc':'#F3DDD5','ll':'#EAE1EF'}
a=[]
def add(s):a.append(s)
def rect(x,y,w,h,fill='paper',r=14,stroke=None):
 add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{P.get(fill,fill)}"'+(f' stroke="{P.get(stroke,stroke)}"' if stroke else '')+'/>')
def text(x,y,t,size=13,fill='teal',serif=False,weight=400,anchor='start',italic=False):
 add(f'<text x="{x}" y="{y}" fill="{P.get(fill,fill)}" font-family="{("DejaVu Serif" if serif else "DejaVu Sans")}" font-size="{size}" font-weight="{weight}" text-anchor="{anchor}"'+(' font-style="italic"' if italic else '')+'>'+html.escape(t)+'</text>')
def line(x,y,w,color='line'):add(f'<path d="M{x} {y}h{w}" stroke="{P.get(color,color)}"/>')
def pill(x,y,w,t,fill='ll',size=9):rect(x,y,w,26,fill,13);text(x+w/2,y+17,t,size,anchor='middle')
def button(x,y,w,t,primary=True):rect(x,y,w,43,'teal' if primary else 'paper',22,None if primary else 'line');text(x+w/2,y+27,t,11,'paper' if primary else 'teal',anchor='middle',weight=500)
def photo(x,y,w,h,person):
 add(f'<svg x="{x}" y="{y}" width="{w}" height="{h}" viewBox="0 0 591.333 887" preserveAspectRatio="xMidYMid slice"><use xlink:href="#portraitAtlas" x="{-person*591.333}"/></svg>')
def mark(x,y,size=32):add(f'<svg x="{x}" y="{y}" width="{size}" height="{size}" viewBox="0 0 44 44"><path d="M25 7C9 6 4 21 15 30c6 5 17 2 18-6C34 11 17 11 14 20c-3 9 4 17 13 17" fill="none" stroke="{P["teal"]}" stroke-width="2.2" stroke-linecap="round"/></svg>')
def shell(x,y,title,nav=True):
 rect(x-4,y+7,358,654,'#DDD8D0',35);rect(x,y,350,650,'paper',32,'#CCCFC5');rect(x+7,y+7,336,636,'ivory',26)
 text(x+24,y+28,'9:41',9,weight=600);text(x+320,y+28,'•••  ▰',9,anchor='end');mark(x+19,y+46,28);text(x+51,y+68,'SoulMatch',22,serif=True);line(x+20,y+85,310)
 if nav:
  rect(x+7,y+590,336,53,'paper',0)
  for i,(s,n) in enumerate([('✧','Discover'),('○','My profile'),('≋','Reflect'),('♧','My world'),('▱','Messages')]):
   text(x+40+i*67,y+612,s,18,anchor='middle');text(x+40+i*67,y+630,n,7,anchor='middle')
 text(x,y-17,title,11,weight=600)
def field(x,y,w,label,value):text(x,y,label,9,'muted');rect(x,y+9,w,37,'paper',9,'line');text(x+11,y+32,value,11)
def score(x,y,n):add(f'<circle cx="{x}" cy="{y}" r="26" fill="none" stroke="{P["ll"]}" stroke-width="4"/><path d="M{x} {y-26}a26 26 0 1 1 -25 34" fill="none" stroke="{P["lavender"]}" stroke-width="4"/>');text(x,y+2,str(n),20,serif=True,anchor='middle');text(x,y+14,'fit / 100',6,anchor='middle')
add('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1320" height="1700" viewBox="0 0 1320 1700">')
add(f'<defs><image id="portraitAtlas" href="data:image/png;base64,{portrait}" width="1774" height="887"/></defs>')
rect(0,0,1320,1700,'ivory',0)
mark(58,38,47);text(112,73,'SoulMatch',39,serif=True);text(112,99,'CONNECTION, CONSIDERED',10,'muted');text(1260,60,'MODERN ROMANCE',10,anchor='end',weight=500);text(1260,83,'Love. Friendship. Your own kind of beginning.',12,'muted',anchor='end')
for i,(name,key) in enumerate([('Deep Teal','teal'),('Muted Coral','coral'),('Soft Peach','peach'),('Warm Ivory','ivory'),('Lavender','lavender')]):
 x=60+i*244;rect(x,125,24,24,key,12,'line');text(x+35,135,name,10);text(x+35,151,P[key],8,'muted')
# Onboarding
x,y=60,210;shell(x,y,'01 / A thoughtful beginning',False)
pill(x+25,y+107,229,'LOVE, FRIENDS, OR A LITTLE OF BOTH',size=8)
text(x+25,y+173,'Find your kind',31,serif=True);text(x+25,y+211,'of connection.',31,'#88695F',serif=True,italic=True)
text(x+25,y+244,'A little science. A little serendipity.',10,'muted');text(x+25,y+263,'A lot of you.',10,'muted')
for i in range(3):photo(x+25+i*104,y+288,94,149,i)
text(x+25,y+465,'What are you open to?',12,serif=True)
pill(x+25,y+480,143,'✓  Find new love','lc',10);pill(x+178,y+480,143,'✓  Find new friends','ll',10)
button(x+25,y+535,296,'Begin my story →');text(x+174,y+604,'Private answers. Mutual choice. Your own pace.',8,'muted',anchor='middle')
# Discover
x,y=485,210;shell(x,y,'02 / Intelligent discovery, human warmth')
text(x+25,y+116,'A little closer to your people.',17,serif=True);pill(x+25,y+128,146,'Love','lc',10);pill(x+178,y+128,146,'Friends','paper',10)
rect(x+20,y+172,310,401,'paper',18);photo(x+20,y+172,310,190,0);pill(x+34,y+327,110,'OPEN TO LOVE','paper',8)
text(x+36,y+397,'Maya, 28',28,serif=True);text(x+36,y+419,'Female · Prague',9,'muted');score(x+284,y+397,78)
text(x+36,y+446,'A home cook, an architect, and a collector',9);text(x+36,y+462,'of very niche playlists. Coffee sometime?',9)
pill(x+36,y+475,81,'Cooking','lc',9);pill(x+125,y+475,68,'Art','lc',9);pill(x+201,y+475,72,'Music','lc',9)
text(x+36,y+519,'Experimental fit points. Interest is not predicted.',8,'muted')
button(x+36,y+531,113,'Maybe later',False);button(x+158,y+531,157,"I’d like to connect ↗")
# Reflection
x,y=910,210;shell(x,y,'03 / Short, private self-discovery')
pill(x+25,y+107,175,'YOUR PERSONALITY · 10 ITEMS','ll',8)
text(x+25,y+164,'A moment for reflection.',25,serif=True);text(x+25,y+193,'Two items per domain. No ideal answers.',9,'muted')
text(x+25,y+225,'PAGE 1 OF 2',8,'muted');rect(x+25,y+237,300,4,'ll',2);rect(x+25,y+237,150,4,'lavender',2)
text(x+25,y+278,'How accurately does this describe you?',11)
rect(x+25,y+296,300,65,'paper',13);text(x+41,y+322,'“I am the life of the party.”',18,serif=True)
for i,(label,sel) in enumerate([('Very inaccurate',False),('Moderately inaccurate',False),('Neither inaccurate nor accurate',True),('Moderately accurate',False),('Very accurate',False)]):
 rect(x+25,y+376+i*34,300,29,'ll' if sel else 'paper',9,'lavender' if sel else 'line');text(x+41,y+395+i*34,('◉  ' if sel else '○  ')+label,9)
text(x+25,y+566,'Experimental short screener · not the BFI-2',8,'muted')
# Interests
x,y=60,940;shell(x,y,'04 / Your interests, and what you want to share')
pill(x+25,y+106,183,'MY WORLD · STEP 3 OF 6','ll',8);text(x+25,y+160,'A little deeper.',28,serif=True);text(x+25,y+188,'Enjoying it and sharing it are different things.',9,'muted');rect(x+25,y+205,300,4,'ll',2);rect(x+25,y+205,150,4,'lavender',2)
rect(x+25,y+231,300,258,'paper',16);text(x+42,y+264,'Cooking',23,serif=True)
for yy,label,value in [(292,'How much do you enjoy it?','Extremely'),(353,'How often do you do it?','Weekly'),(414,'How important is sharing it?','Slightly important')]:
 text(x+42,y+yy,label,9,'muted');rect(x+42,y+yy+10,265,35,'ivory',9);text(x+54,y+yy+33,value+'  ⌄',10)
text(x+25,y+515,'All follow-ups are optional.',9,'muted');button(x+25,y+536,115,'Save for later',False);button(x+151,y+536,174,'Save & continue →')
# Chat + mutual
x,y=485,940;shell(x,y,'05 / Mutual connections, separate conversations')
text(x+25,y+119,'Alex',26,serif=True);pill(x+203,y+99,121,'MUTUAL · FRIENDS','ll',8);text(x+25,y+142,'A little hello. A new possibility.',9,'muted')
rect(x+25,y+164,300,104,'ll',15);text(x+175,y+190,'It’s mutual.',23,serif=True,anchor='middle');text(x+175,y+216,'You both chose a new friendship.',9,anchor='middle');text(x+175,y+241,'No unsolicited messages. Just a good beginning.',8,'muted',anchor='middle')
rect(x+25,y+288,252,63,'paper',14);text(x+41,y+311,'I saw you’re into cooking too.',10);text(x+41,y+329,'What’s your go-to comfort dish?',10)
rect(x+69,y+370,256,64,'teal',14);text(x+85,y+394,'Risotto, with a very optimistic',10,'paper');text(x+85,y+413,'amount of parmesan. Yours?',10,'paper')
rect(x+25,y+452,232,45,'paper',14);text(x+41,y+479,'That’s a promising start :)',10)
rect(x+25,y+531,236,42,'paper',21,'line');text(x+41,y+557,'A little message…',10,'muted');button(x+270,y+531,55,'↗')
# Profile and preferences
x,y=910,940;shell(x,y,'06 / Your identity, intentions and preferences')
text(x+25,y+122,'A story only you can tell.',23,serif=True);text(x+25,y+149,'You can use either space, or both.',9,'muted')
pill(x+25,y+165,143,'✓  Find new love','lc',10);pill(x+178,y+165,147,'✓  Find new friends','ll',10)
field(x+25,y+220,143,'My name','Alex');field(x+178,y+220,147,'My gender','Nonbinary  ⌄')
text(x+25,y+294,'In Love, I am interested in',9,'muted');pill(x+25,y+307,83,'Male','lc',10);pill(x+117,y+307,92,'Female','lc',10);pill(x+219,y+307,106,'Nonbinary','lc',10)
rect(x+25,y+354,300,91,'paper',15);text(x+41,y+380,'Preferred age',12,serif=True);line(x+43,y+403,262);add(f'<circle cx="{x+95}" cy="{y+403}" r="6" fill="{P["teal"]}"/><circle cx="{x+244}" cy="{y+403}" r="6" fill="{P["teal"]}"/>');text(x+41,y+428,'24–38  ·  soft preference',9,'muted')
rect(x+25,y+459,300,58,'ll',13);text(x+41,y+482,'Your height story · optional',11,serif=True);text(x+41,y+501,'Everyday experiences, rather than a number.  →',8,'muted')
button(x+25,y+537,300,'Save my story →')
line(60,1644,1200)
text(60,1670,'DESIGN REFERENCE · IMPLEMENTED IN R SHINY',9,weight=500);text(1260,1670,'Illustrative fit scores · Fictional AI demo portraits · No validated probability claims',8,'muted',anchor='end')
add('</svg>')
out=root/'design/mobile-design-board.svg';out.write_text(''.join(a))
try:
 import cairosvg
 cairosvg.svg2png(url=str(out),write_to=str(out.with_suffix('.png')))
 print(out.with_suffix('.png'))
except ImportError:print('SVG written; install cairosvg for PNG output.')
