// All copy on the site, in Swedish (default, at /) and English (at /en/).
// Keep both languages in step: the same keys, the same claims.
import { site } from './site';

export type Lang = 'sv' | 'en';

export type FeatureKey = 'overview' | 'trips' | 'driving' | 'commuting';

interface Link {
  label: string;
  href: string;
}

interface FaqItem {
  q: string;
  a: string;
  /** Shown under the answer. */
  link?: Link;
}

interface UpdateOption {
  title: string;
  text: string;
  /** Shown in monospace under the text, e.g. an address to copy. */
  code?: string;
  link?: Link;
}

// Identity helpers: full type checking of the optional fields in both languages.
const faqItems = (items: FaqItem[]) => items;
const updateOptions = (options: UpdateOption[]) => options;

/** owner/name, as the GitHub CLI wants it. */
const repoSlug = site.repo.replace('https://github.com/', '');

const sv = {
  htmlLang: 'sv-SE',
  meta: {
    title: 'Trakta – traktamente, körjournal och reseavdrag',
    description:
      'Håll koll på traktamente, tjänstekörning och reseavdrag under året och se exakt vad du ska fylla i i deklarationen. Gratis, helt offline och dina data stannar i telefonen.',
  },
  nav: { features: 'Funktioner', mission: 'Varför Trakta', about: 'Om mig', faq: 'Frågor', download: 'Ladda ner' },
  switchLang: { label: 'English', href: '/en/' },
  hero: {
    eyebrow: 'För dig som reser i jobbet',
    title: 'Alla dina reseavdrag. Rätt i deklarationen.',
    lead: 'Trakta räknar ut traktamente, milersättning och reseavdrag enligt Skatteverkets regler – och visar exakt vilket belopp som ska in i vilken ruta. Gratis, helt offline, och dina uppgifter lämnar aldrig telefonen.',
    note: 'Gratis · Öppen källkod · Ingen inloggning · Ingen reklam',
  },
  /** The buttons on the home page. */
  get: {
    downloadFor: 'Ladda ner för',
    android: 'Android',
    later: 'Kommer senare till',
    iphone: 'iPhone',
  },
  mission: {
    title: 'Varför Trakta finns',
    lead: 'Avdrag för resor i jobbet är pengar som är dina – men reglerna är krångliga och det är lätt att tappa bort underlagen under året. Trakta gör det enkelt att göra rätt.',
    pillars: [
      {
        icon: 'explain',
        title: 'Varje krona förklarad',
        text: 'Trakta följer Skatteverkets schablonbelopp och regler och visar varför varje dag blir som den blir: hel eller halv dag, måltider, land.',
      },
      {
        icon: 'lock',
        title: 'Dina data, din telefon',
        text: 'Ingen server, inget konto, ingen internetåtkomst. Allt sparas krypterat i telefonen.',
      },
      {
        icon: 'gift',
        title: 'Gratis',
        text: 'Ingen reklam, ingen spårning och inga köp i appen. Trakta är byggt för att vara till nytta.',
      },
    ],
  },
  features: {
    title: 'Fyra flikar. Hela året.',
    lead: 'Allt som påverkar dina reseavdrag på ett ställe – och svaret på vad som ska in i deklarationen.',
    items: [
      {
        key: 'overview',
        tab: 'Översikt',
        title: 'Se vad du kan dra av – och var',
        text: 'Översikten visar årets förväntade avdrag och exakt vilket belopp som ska in i vilken ruta i deklarationen.',
        points: ['Årets avdrag i ett tal', 'Belopp per ruta i deklarationen'],
        alt: 'Trakta: översikten med förväntat avdrag och belopp per ruta i deklarationen',
      },
      {
        key: 'trips',
        tab: 'Resor',
        title: 'Traktamente utan krångel',
        text: 'Lägg upp en tjänsteresa, granska varje dag och se traktamente och nattraktamente räknas ut – i Sverige eller utomlands, med Skatteverkets normalbelopp för varje land.',
        points: ['Hel- och halvdagar, måltider och logi', 'Normalbelopp för nästan 200 länder', 'Anteckningar och dokument som biljetter och kvitton'],
        alt: 'Trakta: en tjänsteresa med traktamente och avdrag i ruta 2.2',
      },
      {
        key: 'driving',
        tab: 'Körjournal',
        title: 'Körjournal för tjänstekörning',
        text: 'Logga körningar i jobbet med bil, sträcka och syfte. Trakta räknar milersättningen per bil och håller ordning på trängselskatt, vägavgifter och kvitton.',
        points: ['Egen bil eller förmånsbil, el eller fossil', 'Årets total per bil'],
        alt: 'Trakta: körjournalen med tjänstekörningar och årets milersättning',
      },
      {
        key: 'commuting',
        tab: 'Reseavdrag',
        title: 'Reseavdrag som sköter sig själv',
        text: 'Lägg upp din pendling en gång. Trakta räknar dagarna efter ditt schema, hoppar över helgdagar och tjänsteresor och visar hur nära du är beloppsgränsen.',
        points: ['Följ enkelt med kalendern', 'Hantera pendling utgifter',],
        alt: 'Trakta: reseavdrag med pendlingskalender och ruta 2.1',
      },
    ],
  },
  openSource: {
    title: 'Öppen källkod',
    lead: 'Koden bakom Trakta är öppen och licensierad under Apache License 2.0. Du behöver inte lita på mitt ord – det går att kontrollera.',
    points: [
      'Läs exakt hur varje belopp räknas ut',
      'Kontrollera att appen inte gör några nätverksanrop',
      'Rapportera fel och bidra med förbättringar',
    ],
    button: 'Källkoden på GitHub',
  },
  about: {
    title: 'Om mig',
    lead: 'Hej! Jag heter Dan och är mjukvaruutvecklare.',
    text: [
      'Jag ville ha ett enkelt sätt att hålla koll på traktamente, körjournal och reseavdrag – och att veta vad som faktiskt ska in i deklarationen. Så jag byggde Trakta, först för mig själv.',
      'Appen är ett sidoprojekt. Den är gratis, fungerar helt offline och samlar inte in något om dig. Har du synpunkter eller hittar ett fel hör jag gärna av dig.',
    ],
    linkedIn: 'Dan på LinkedIn',
    contact: 'Skicka e-post',
  },
  support: {
    title: 'Stötta Trakta',
    text: 'Trakta är gratis och byggs på min fritid. Vill du stötta det jag försöker göra med Trakta och hjälpa till att täcka kostnaderna för publicering och drift kan du bjuda mig på en kaffe.',
    button: 'Bjud på en kaffe',
    footer: 'Stötta Trakta',
  },
  faq: {
    title: 'Vanliga frågor',
    items: faqItems([
      {
        q: 'Är Trakta skatterådgivning?',
        a: 'Nej. Trakta räknar med Skatteverkets publicerade schablonbelopp och regler så som jag har förstått dem, men det kan finnas fel och din situation kan vara annorlunda. Du ansvarar själv för din deklaration – kontrollera beloppen och fråga Skatteverket om du är osäker.',
      },
      {
        q: 'Var sparas mina uppgifter?',
        a: 'Bara i din telefon, i en krypterad databas. Appen har ingen internetåtkomst, inget konto och skickar ingenting någonstans. Tar du bort appen försvinner också uppgifterna, om du inte har en säkerhetskopia.',
      },
      {
        q: 'Vad händer när jag byter telefon?',
        a: 'Skapa en säkerhetskopia under Inställningar. Den blir en krypterad fil, skyddad med ett lösenord du väljer, och du sparar den där du vill – till exempel i Google Drive, iCloud Drive eller i ett mejl till dig själv. På den nya telefonen väljer du ”Återställ en säkerhetskopia”. När Trakta finns för iPhone fungerar det mellan Android och iPhone åt båda hållen.',
      },
      {
        q: 'Vad kostar det?',
        a: 'Ingenting. Ingen reklam, inga köp i appen och ingen spårning.',
      },
      {
        q: 'Vilka år stöds?',
        a: 'Inkomståret 2026. Skatteverkets belopp ändras varje år, så appen uppdateras inför varje nytt inkomstår.',
      },
      {
        q: 'Finns det något Trakta inte räknar med?',
        a: 'Ja. Vid långa förrättningar, mer än tre månader på samma ort, sänks det skattefria traktamentet. Det räknar Trakta inte med än. Har du en sådan resa, kontrollera beloppen själv. Trakta hanterar inte heller dubbel bosättning eller reseavdrag med kollektivtrafik och cykel.',
      },
      {
        q: 'Varför finns Trakta inte i Google Play eller App Store?',
        a: 'Trakta testas fortfarande, och appen kommer till butikerna när den är redo. Android-versionen kan du redan nu ladda ner direkt härifrån. Versionen för iPhone kommer senare.',
        link: { label: 'Ladda ner för Android', href: '/ladda-ner/' },
      },
      {
        q: 'Är det säkert att installera en APK-fil?',
        a: `Ja, så länge du hämtar den från rätt ställe: trakta.app eller github.com/${repoSlug}. Varje version är signerad med Traktas egen nyckel, och Android installerar inga uppdateringar som är signerade med en annan. Kontrollsummor för varje version finns på GitHub. Appen har dessutom ingen internetbehörighet alls, så den kan inte skicka något någonstans.`,
        link: { label: 'Så kontrollerar du nedladdningen', href: '/ladda-ner/#kontrollera' },
      },
      {
        q: 'Hur uppdaterar jag appen?',
        a: 'Appen har ingen internetåtkomst och kan därför inte själv kolla om det finns en ny version. Titta in på nedladdningssidan då och då, bevaka nya versioner på GitHub eller använd appen Obtainium, som håller koll åt dig. Den nya versionen installeras ovanpå den gamla och dina uppgifter finns kvar. Har du testversionen från Google Play sköter Google Play uppdateringarna.',
        link: { label: 'Mer om uppdateringar', href: '/ladda-ner/#uppdateringar' },
      },
      {
        q: 'Är Trakta öppen källkod?',
        a: `Ja. Koden finns på GitHub under Apache License 2.0, så vem som helst kan läsa hur beloppen räknas ut, rapportera fel och bidra. Namnet Trakta och ikonen omfattas av en varumärkespolicy: publicerar du en ändrad version behöver den ett eget namn och en egen ikon.`,
        link: { label: 'Källkoden på GitHub', href: site.repo },
      },
    ]),
  },
  download: {
    href: '/ladda-ner/',
    meta: {
      title: 'Ladda ner för Android',
      description:
        'Ladda ner Trakta för Android. Gratis, öppen källkod och inget konto – dina uppgifter stannar i telefonen. Så installerar, uppdaterar och kontrollerar du appen.',
    },
    title: 'Ladda ner Trakta',
    lead: 'Gratis och med öppen källkod. Du behöver inget konto, och allt du registrerar stannar i din telefon.',
    beta: {
      label: 'Beta',
      text: 'Trakta är i beta: appen används redan på riktigt, men testas och förbättras fortfarande. Hittar du något som inte stämmer får du gärna höra av dig till',
    },
    android: {
      id: 'android',
      title: 'Android',
      button: 'Ladda ner för Android',
      version: 'Version',
      soon: 'Första versionen kommer snart',
      releases: 'Alla versioner på GitHub',
      stepsTitle: 'Så installerar du',
      steps: [
        'Ladda ner trakta.apk till telefonen.',
        'Öppna filen. Första gången frågar Android om webbläsaren får installera appar – tillåt det. Det behöver du bara göra en gång.',
        'Tryck på Installera och öppna sedan Trakta.',
      ],
      note: 'Android kan varna för att appen inte kommer från Google Play. Det är väntat för appar som laddas ner direkt.',
    },
    updates: {
      id: 'uppdateringar',
      title: 'Uppdateringar',
      lead: 'Trakta har ingen internetåtkomst och kan därför inte själv kolla om det finns en ny version. Välj det sätt som passar dig:',
      options: updateOptions([
        {
          title: 'Titta in här',
          text: 'Kom tillbaka till den här sidan då och då. Vilken version du har ser du i Trakta under Inställningar.',
        },
        {
          title: 'Bevaka på GitHub',
          text: 'Med ett GitHub-konto kan du bevaka nya versioner (releases) i projektet och få besked när en ny kommer.',
          link: { label: 'Versionerna på GitHub', href: site.releases },
        },
        {
          title: 'Obtainium',
          text: 'Obtainium är en app med öppen källkod som installerar och uppdaterar appar direkt från GitHub. Lägg till den här adressen i den:',
          code: site.repo,
          link: { label: 'Om Obtainium', href: site.obtainium },
        },
      ]),
      after: 'Den nya versionen installeras ovanpå den gamla, och allt du har registrerat finns kvar.',
    },
    play: {
      id: 'google-play',
      title: 'Har du testversionen från Google Play?',
      text: 'Då kan du fortsätta använda den – Google Play sköter uppdateringarna. Vill du hellre byta till versionen härifrån flyttar du dina uppgifter med en säkerhetskopia. Versionerna är signerade med olika nycklar, och därför installerar Android inte den ena ovanpå den andra.',
      steps: [
        'Skapa en säkerhetskopia i Trakta under Inställningar → Säkerhetskopia. Spara filen utanför appen, till exempel i Hämtade filer eller Google Drive.',
        'Avinstallera Trakta. Allt i appen raderas, så kontrollera först att säkerhetskopian är sparad.',
        'Ladda ner och installera Trakta härifrån.',
        'Öppna Trakta, välj ”Återställ en säkerhetskopia” och ange lösenordet.',
      ],
    },
    iphone: {
      id: 'iphone',
      title: 'iPhone',
      text: 'Trakta för iPhone kommer senare, men det finns inget datum ännu. Följ projektet på GitHub om du vill veta när.',
      link: 'Trakta på GitHub',
    },
    verify: {
      id: 'kontrollera',
      title: 'Kontrollera nedladdningen',
      lead: 'För dig som vill veta exakt vad du installerar.',
      cert: 'Appen är signerad med ett certifikat som har det här SHA-256-fingeravtrycket:',
      certCheck: 'Jämför med vad Androids verktyg apksigner visar:',
      sums: { before: 'Varje version på GitHub har filen', after: 'med SHA-256-kontrollsummor för filerna.' },
      attest:
        'Varje APK byggs från källkoden i GitHub Actions och får ett intyg om var och hur den byggdes (build provenance). Med GitHub CLI kontrollerar du intyget så här:',
    },
    build: {
      id: 'bygg-sjalv',
      title: 'Bygg själv',
      text: 'All källkod finns på GitHub, tillsammans med instruktioner för att bygga appen.',
      button: 'Källkoden på GitHub',
    },
  },
  footer: {
    disclaimer: 'Trakta är inte skatterådgivning och har ingen koppling till Skatteverket. Du ansvarar själv för din deklaration.',
    label: 'Sidfot',
    source: 'Källkod på GitHub',
    privacy: 'Integritetspolicy',
    terms: 'Användarvillkor',
    contact: 'Kontakt',
    privacyHref: '/integritet/',
    termsHref: '/villkor/',
  },
  legal: { updated: 'Senast uppdaterad', back: 'Till startsidan' },
};

const en: typeof sv = {
  htmlLang: 'en',
  meta: {
    title: 'Trakta – per diem, driving log and commuting deductions',
    description:
      'Track per diem, business driving and commuting through the year and see exactly what to enter in your Swedish tax return. Free, fully offline, and your data stays on your phone.',
  },
  nav: { features: 'Features', mission: 'Why Trakta', about: 'About', faq: 'FAQ', download: 'Download' },
  switchLang: { label: 'Svenska', href: '/' },
  hero: {
    eyebrow: 'For people who travel for work',
    title: 'All your travel deductions. Right in your tax return.',
    lead: 'Trakta works out per diem, mileage and the commuting deduction by Skatteverket’s rules – and shows exactly which amount goes in which box. Free, fully offline, and your data never leaves your phone.',
    note: 'Free · Open source · No sign-in · No ads',
  },
  get: {
    downloadFor: 'Download for',
    android: 'Android',
    later: 'Coming later to',
    iphone: 'iPhone',
  },
  mission: {
    title: 'Why Trakta exists',
    lead: 'Deductions for work travel are your money – but the rules are complicated and records get lost over the year. Trakta makes it easy to get it right.',
    pillars: [
      {
        icon: 'explain',
        title: 'Every krona explained',
        text: 'Trakta follows Skatteverket’s standard amounts and rules and shows why each day comes out the way it does: full or half day, meals, country.',
      },
      {
        icon: 'lock',
        title: 'Your data, your phone',
        text: 'No server, no account, no internet access. Everything is stored encrypted on your phone.',
      },
      {
        icon: 'gift',
        title: 'Free',
        text: 'No ads, no tracking and no in-app purchases. Trakta is built to be useful.',
      },
    ],
  },
  features: {
    title: 'Four tabs. The whole year.',
    lead: 'Everything that affects your travel deductions in one place – and the answer to what goes in your tax return.',
    items: [
      {
        key: 'overview',
        tab: 'Overview',
        title: 'See what you can deduct – and where',
        text: 'The overview shows the year’s expected deduction and exactly which amount goes in which box of your tax return.',
        points: ['The year’s deduction in one number', 'Amounts per box of the tax return'],
        alt: 'Trakta: the overview with the expected deduction and amounts per tax return box',
      },
      {
        key: 'trips',
        tab: 'Trips',
        title: 'Per diem without the hassle',
        text: 'Add a business trip, review each day and see per diem and night allowance worked out – in Sweden or abroad, with Skatteverket’s normalbelopp for every country.',
        points: ['Full and half days, meals and lodging', 'Normalbelopp for almost 200 countries', 'Notes and documents like tickets and receipts'],
        alt: 'Trakta: a business trip with per diem and the box 2.2 deduction',
      },
      {
        key: 'driving',
        tab: 'Driving log',
        title: 'A driving log for business driving',
        text: 'Log drives in your job with car, distance and purpose. Trakta works out the mileage allowance per car and keeps congestion tax, tolls and receipts in order.',
        points: ['Own car or company car, electric or fossil', 'The year’s total per car'],
        alt: 'Trakta: the driving log with business drives and the year’s mileage allowance',
      },
      {
        key: 'commuting',
        tab: 'Commuting',
        title: 'A commuting deduction that runs itself',
        text: 'Set up your commute once. Trakta counts the days from your schedule, skips public holidays and business trips, and shows how close you are to the limit.',
        points: ['Easily track using calendar', 'Track commuting costs'],
        alt: 'Trakta: the commuting deduction with the month calendar and box 2.1',
      },
    ],
  },
  openSource: {
    title: 'Open source',
    lead: 'The code behind Trakta is open and licensed under the Apache License 2.0. You don’t have to take my word for it – you can check.',
    points: [
      'Read exactly how every amount is calculated',
      'Check that the app makes no network requests',
      'Report mistakes and contribute improvements',
    ],
    button: 'Source code on GitHub',
  },
  about: {
    title: 'About me',
    lead: 'Hi! I’m Dan, a software engineer.',
    text: [
      'I wanted a simple way to keep track of per diem, my driving log and the commuting deduction – and to know what actually goes in the tax return. So I built Trakta, first for myself.',
      'The app is a side project. It’s free, works fully offline and collects nothing about you. If you have feedback or find a mistake, I’d love to hear from you.',
    ],
    linkedIn: 'Dan on LinkedIn',
    contact: 'Send an email',
  },
  support: {
    title: 'Support Trakta',
    text: 'Trakta is free and built in my spare time. If you want to support what I’m trying to do with Trakta and help cover publishing and hosting costs, you can buy me a coffee.',
    button: 'Buy me a coffee',
    footer: 'Support Trakta',
  },
  faq: {
    title: 'Questions',
    items: faqItems([
      {
        q: 'Is Trakta tax advice?',
        a: 'No. Trakta calculates with Skatteverket’s published standard amounts and rules as I understand them, but there may be mistakes and your situation may differ. You are responsible for your own tax return – check the amounts and ask Skatteverket if you are unsure.',
      },
      {
        q: 'Where is my data stored?',
        a: 'Only on your phone, in an encrypted database. The app has no internet access, no account and sends nothing anywhere. If you remove the app, the data goes with it unless you have a backup.',
      },
      {
        q: 'What happens when I switch phones?',
        a: 'Create a backup under Settings. It is an encrypted file, protected by a password you choose, and you save it wherever you like – for example Google Drive, iCloud Drive or an email to yourself. On the new phone, choose “Restore a backup”. Once Trakta is available for iPhone, it works between Android and iPhone in both directions.',
      },
      {
        q: 'What does it cost?',
        a: 'Nothing. No ads, no in-app purchases and no tracking.',
      },
      {
        q: 'Which years are supported?',
        a: 'Income year 2026. Skatteverket’s amounts change every year, so the app is updated before each new income year.',
      },
      {
        q: 'Is there anything Trakta does not take into account?',
        a: 'Yes. On long stays, more than three months at the same place, the tax-free per diem is reduced. Trakta does not apply that yet. If you have such a trip, check the amounts yourself. Trakta also does not handle double residence (dubbel bosättning) or the commuting deduction for public transport and bicycles.',
      },
      {
        q: 'Why isn’t Trakta in Google Play or the App Store?',
        a: 'Trakta is still being tested, and it will come to the stores when it is ready. On Android you can already download it directly from here. The iPhone version comes later.',
        link: { label: 'Download for Android', href: '/en/download/' },
      },
      {
        q: 'Is it safe to install an APK file?',
        a: `Yes, as long as you get it from the right place: trakta.app or github.com/${repoSlug}. Every version is signed with Trakta’s own key, and Android installs no update signed with a different one. Checksums for every version are on GitHub. And the app has no internet permission at all, so it cannot send anything anywhere.`,
        link: { label: 'How to verify the download', href: '/en/download/#verify' },
      },
      {
        q: 'How do I update the app?',
        a: 'The app has no internet access, so it cannot check for a new version itself. Visit the download page now and then, watch for new versions on GitHub, or use the Obtainium app, which keeps track for you. The new version installs over the old one and your data stays. If you have the test version from Google Play, Google Play takes care of updates.',
        link: { label: 'More about updates', href: '/en/download/#updates' },
      },
      {
        q: 'Is Trakta open source?',
        a: `Yes. The code is on GitHub under the Apache License 2.0, so anyone can read how the amounts are calculated, report mistakes and contribute. The name Trakta and the icon are covered by a trademark policy: if you publish a modified version, it needs its own name and icon.`,
        link: { label: 'Source code on GitHub', href: site.repo },
      },
    ]),
  },
  download: {
    href: '/en/download/',
    meta: {
      title: 'Download for Android',
      description:
        'Download Trakta for Android. Free, open source and no account – your data stays on your phone. How to install, update and verify the app.',
    },
    title: 'Download Trakta',
    lead: 'Free and open source. No account needed, and everything you enter stays on your phone.',
    beta: {
      label: 'Beta',
      text: 'Trakta is in beta: people already use it for real, but it is still being tested and improved. If something doesn’t look right, please get in touch at',
    },
    android: {
      id: 'android',
      title: 'Android',
      button: 'Download for Android',
      version: 'Version',
      soon: 'First release coming soon',
      releases: 'All versions on GitHub',
      stepsTitle: 'How to install',
      steps: [
        'Download trakta.apk to your phone.',
        'Open the file. The first time, Android asks whether your browser may install apps – allow it. You only need to do this once.',
        'Tap Install, then open Trakta.',
      ],
      note: 'Android may warn you that the app does not come from Google Play. That is expected for apps downloaded directly.',
    },
    updates: {
      id: 'updates',
      title: 'Updates',
      lead: 'Trakta has no internet access, so it cannot check for a new version itself. Pick what suits you:',
      options: updateOptions([
        {
          title: 'Come back here',
          text: 'Check this page now and then. You can see which version you have in Trakta under Settings.',
        },
        {
          title: 'Watch on GitHub',
          text: 'With a GitHub account you can watch the project’s releases and get notified when a new one is out.',
          link: { label: 'Releases on GitHub', href: site.releases },
        },
        {
          title: 'Obtainium',
          text: 'Obtainium is an open source app that installs and updates apps straight from GitHub. Add this address to it:',
          code: site.repo,
          link: { label: 'About Obtainium', href: site.obtainium },
        },
      ]),
      after: 'A new version installs over the old one, and everything you have entered stays.',
    },
    play: {
      id: 'google-play',
      title: 'Using the test version from Google Play?',
      text: 'Then you can keep using it – Google Play takes care of updates. If you would rather switch to the version from here, move your data with a backup. The two versions are signed with different keys, which is why Android will not install one over the other.',
      steps: [
        'Create a backup in Trakta under Settings → Backup. Save the file outside the app, for example in Downloads or Google Drive.',
        'Uninstall Trakta. Everything in the app is deleted, so make sure the backup is saved first.',
        'Download and install Trakta from here.',
        'Open Trakta, choose “Restore a backup” and enter the password.',
      ],
    },
    iphone: {
      id: 'iphone',
      title: 'iPhone',
      text: 'Trakta for iPhone is coming later, but there is no date yet. Follow the project on GitHub if you want to know when.',
      link: 'Trakta on GitHub',
    },
    verify: {
      id: 'verify',
      title: 'Verify the download',
      lead: 'For those who want to know exactly what they are installing.',
      cert: 'The app is signed with a certificate that has this SHA-256 fingerprint:',
      certCheck: 'Compare it with what Android’s apksigner tool shows:',
      sums: { before: 'Every version on GitHub includes', after: 'with the SHA-256 checksums of its files.' },
      attest:
        'Every APK is built from the source code in GitHub Actions and gets an attestation of where and how it was built (build provenance). With the GitHub CLI you can verify it like this:',
    },
    build: {
      id: 'build',
      title: 'Build it yourself',
      text: 'All the source code is on GitHub, along with instructions for building the app.',
      button: 'Source code on GitHub',
    },
  },
  footer: {
    disclaimer: 'Trakta is not tax advice and is not affiliated with Skatteverket. You are responsible for your own tax return.',
    label: 'Footer',
    source: 'Source code on GitHub',
    privacy: 'Privacy policy',
    terms: 'Terms of use',
    contact: 'Contact',
    privacyHref: '/en/privacy/',
    termsHref: '/en/terms/',
  },
  legal: { updated: 'Last updated', back: 'Back to the home page' },
};

export const t = { sv, en } as const;

/** The commands shown under "Verify the download". Not translated. */
export const commands = {
  cert: 'apksigner verify --print-certs trakta.apk',
  attest: `gh attestation verify trakta.apk --repo ${repoSlug}`,
} as const;
