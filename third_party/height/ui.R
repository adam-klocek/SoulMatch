library(shiny)

shinyUI(pageWithSidebar(
  # Application title
  headerPanel("Brněnský dotazník výšky (zkrácená verze)"),
  sidebarPanel(
    radioButtons("sex", label = "Jste:",
                 choices = list('muž'=0, 'zena'=1)),
    radioButtons(inputId="p1", label = "Mám vhodnou výšku na hraní basketbalu nebo volejbalu.", 
                choices = list('Silně nesouhlasím' = 0,
                               'Nesouhlasím' = 1,
                               'Souhlasím' = 2,
                               'Silně souhlasím' = 3
                )),
    radioButtons(inputId="p2", label = "Slýchávám narážky na to, že jsem vysoký/á.", 
                 choices = list('Silně nesouhlasím' = 0,
                                'Nesouhlasím' = 1,
                                'Souhlasím' = 2,
                                'Silně souhlasím' = 3
                 )),
    radioButtons(inputId="p3", label = "Lidem, kteří na koncertě stojí za mnou, většinou má postava dost brání ve výhledu.", 
                 choices = list('Silně nesouhlasím' = 0,
                                'Nesouhlasím' = 1,
                                'Souhlasím' = 2,
                                'Silně souhlasím' = 3
                 )),
    radioButtons(inputId="p4", label = "Když chci někoho obejmout, většinou se musím sklonit.", 
                 choices = list('Silně nesouhlasím' = 0,
                                'Nesouhlasím' = 1,
                                'Souhlasím' = 2,
                                'Silně souhlasím' = 3
                 )),
    radioButtons(inputId="p5", label = "Často si musím dávat pozor, abych se neuhodil/a hlavou např. o nízký strop nebo rám dveří.", 
                 choices = list('Silně nesouhlasím' = 0,
                                'Nesouhlasím' = 1,
                                'Souhlasím' = 2,
                                'Silně souhlasím' = 3
                 )),
    radioButtons(inputId="p6", label = "Často potřebuji stoličku, abych dosáhl/a na něco, na co jiní lidé dosáhnou normálně.", 
                 choices = list('Silně nesouhlasím' = 0,
                                'Nesouhlasím' = 1,
                                'Souhlasím' = 2,
                                'Silně souhlasím' = 3
                 )),
    radioButtons(inputId="p7", label = "Jednou z prvních věcí, které si na mně lidé všimnou, je to, jak moc jsem malý/á.", 
                 choices = list('Silně nesouhlasím' = 0,
                                'Nesouhlasím' = 1,
                                'Souhlasím' = 2,
                                'Silně souhlasím' = 3
                 )),
    radioButtons(inputId="p8", label = "Často musím stát na špičkách, abych lépe viděl/a.", 
                 choices = list('Silně nesouhlasím' = 0,
                                'Nesouhlasím' = 1,
                                'Souhlasím' = 2,
                                'Silně souhlasím' = 3
                 )),
    radioButtons(inputId="p9", label = "V autobuse mívám dostatek prostoru pro nohy.", 
                 choices = list('Silně nesouhlasím' = 0,
                                'Nesouhlasím' = 1,
                                'Souhlasím' = 2,
                                'Silně souhlasím' = 3
                 )),
    radioButtons(inputId="p10", label = "Kvůli mé menší výšce lidé hádají, že jsem mladší, než ve skutečnosti jsem.", 
                 choices = list('Silně nesouhlasím' = 0,
                                'Nesouhlasím' = 1,
                                'Souhlasím' = 2,
                                'Silně souhlasím' = 3
                 )),
    radioButtons(inputId="p11", label = "Když mluvím s jinými dospělými a chci se jim dívat do oči, častěji na ně spíš vzhlížím nahoru.", 
                 choices = list('Silně nesouhlasím' = 0,
                                'Nesouhlasím' = 1,
                                'Souhlasím' = 2,
                                'Silně souhlasím' = 3
                 )),
    
    actionButton(inputId="button", label="Let's measure!"),
    hr(), 
    width = 6),
  mainPanel(
    HTML("<p>Pro zobrazení výsledků vyplňte dotazník a klikněte na  &bdquo;přiložit pravítko&ldquo;.</p>"),
    HTML("<h3>Vaše &bdquo;psychologická&ldquo; výška</h3>"),
    h4(textOutput("iq")),
    HTML("<h3>Vaše &bdquo;skutečná&ldquo; výška</h3>"),
    h4(textOutput("vyska")),
    h4(textOutput("cm")),
    hr(),
    HTML("<p>Uváděné výsledky jsou založené na příležitostném vzorku 4885 respondentů (30 % mužů, 60 % žen) 
ve věku 17-58 let, s průměrem 23,3 (<i>SD</i> = 4,3); 92 % respondentů bylo ve věku 18-28 let. 
Sběr dat probíhal online s náborem skrze facebookové skupiny, podrobně vzorek popisuje Rečka (2018).</p>
<p>Dotazník lze velmi dobře popsat bifaktorovým modelem, kde jsou všechny položky sycené celkovým faktorem 
(45 % vysvětleného rozptylu) a negativně formulované položky rovněž i specifickým faktorem
(11 % celkového vysvětleného rozptylu). Model nicméně není invariantní pro muže a ženy a jejich skóry 
tak nelze přímo srovnávat. 
Shoda konfigurálního konfirmačního CFA modelu s daty, odhadnutého prostřednictvím MLR estimátoru, je 
&chi;<sup>2</sup>(76) = 339,4, <i>p</i> < 0,001, <i>TLI</i> = 0.985, <i>RMSEA</i> = 0.038 s 90% 
<i>CI</i> = [0.034, 0.042], <i>SRMR</i> = 0.019. Reliabilita odhadnutá koeficientem McDonaldova celková omega 
byla &omega;<sub><i>t</i></sub> = 0,93 pro muže, pro ženy pak &omega;<sub><i>t</i></sub> = 0,95. Konvergentní validita 
vyjádřená korelací součtového skóre s uvedenou výškou v centimetrech byla 
<i>r</i> = 0,86 pro muže, pro ženy <i>r</i> = 0,89. Tyto hodnoty byly použity v této aplikaci. </p>
<p>Kromě toho lze zvážit konstruktovou validitu odhadnutou prostřednictvím strukturního modelu; 
celkový i negativní faktor vysvětlily většinu rozptylu uváděné výšky v centimetrech, <i>R<sup>2</sup></i> = 0,81 
pro muže, pro ženy pak <i>R<sup>2</sup></i> = 0,84. </p>
         <p>Deskriptivy vzorku:<br>
         <small>(objeví se až po zobrazení výsledků dotazníku)</small></p>"),
    tableOutput("normy"),
    hr(),
    HTML("<p><i>Tento jednoduchý nástroj byl vyvinut na Katedře psychologie 
         Fakulty sociálních studií Masarykovy univerzity 
         za účelem demonstrace některých náležitostí měření v psychologii a příbuzných oborech 
         - primárně slouží jako učební 
         pomůcka v rámci kurzu PSY259: Základy psychometriky. <br>
         Je nezbytné podotknout, že aktuálně vyhodnocení testu probíbá pouze s využitím Klasické testové teorie. 
         Pro predikci výšky je tedy používán prostý součet položek, což značně snižuje kvalitu takové predikce, 
         zejména z důvodu nelineárního vztahu hrubého skóre a měřeného rysu 
         (zejména v případě extrémních hodnot), a z důvodu nižší reliability součtového skóre oproti 
         odhadu latentního rysu (odhadu faktorového skóre). Toto zkreslení je však relativně malé.</i></p>
         <p>&copy; 2019 Hynek Cígler, <a href='http://psych.fss.muni.cz'>Katedra psychologie FSS MU</a>.<br>
         Dále pak Karel Rečka (2018) vytvořil položky a datovou matici, která posloužila pro veškeré výpočty; 
         Martin Tancoš (2019) pak provedl výběr z těchto položek.<br>
Zdrojový kód aplikace <a href=''>je veřejně k dispozici</a>.</p>
         
         <ol>
         <li>Rečka, K. (2018). <i>Dotazník výšky a váhy</i>. Brno, Masarykova univerzita: nepublikovaná diplomová práce. <a href='https://is.muni.cz/th/ug7c2/'>Dostupné online</a>.
         <li>Tancoš, M. (2019). <i>Vliv verbálních kotev Likertovy škály na psychometrické charakteristiky dotazníků</i>. Brno, Masarykova univerzita: nepublikovaná diplomová práce. <a href='https://is.muni.cz/th/uk8cb/'>Dostupné online</a>.
         </ol>"), 
            width = 6
            
  ))
  
)
