/**
 * Cloud Functions — Ma Billetterie Sereine
 * Node.js 22  |  europe-west1
 *
 * Fonctions :
 *   syncOpenAgenda    → toutes les 6h (planifiée)
 *   syncTicketmaster  → toutes les 6h (planifiée)
 *   syncAllSources    → HTTP manuel (trigger de test)
 *   parsetickettext   → Magic Scan (inchangée)
 *
 * Déploiement :
 *   firebase deploy --only functions
 */

import { onSchedule }        from "firebase-functions/v2/scheduler";
import { onRequest }         from "firebase-functions/v2/https";
import { initializeApp }     from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import fetch                 from "node-fetch";

initializeApp();
const db = getFirestore();

// ─── CONFIGURATION ────────────────────────────────────────────────────────────
const CONFIG = {
  openagenda: {
    apiKey:   "d0f99c185b684234b860235f32b56d1d",   // ← ta clé publique OpenAgenda
    agendaUid: null,        // null = tous les agendas publics France
    size:      100,         // événements par page
    maxPages:  10,          // 10 x 100 = 1000 événements max par sync
  },
  ticketmaster: {
    apiKey:   "rsGNJosVrvGVoZj5kG8rjdgqSy9TC6v4",  // ← clé developer.ticketmaster.com
    countryCode: "FR",
    size:      100,
    maxPages:  5,
  },
};

// ─── CATÉGORIES ───────────────────────────────────────────────────────────────
function mapOpenAgendaCategory(tags = []) {
  const t = tags.join(" ").toLowerCase();
  if (t.includes("concert") || t.includes("musique")) return "Concert";
  if (t.includes("festival"))                          return "Festival";
  if (t.includes("théâtre") || t.includes("theatre")) return "Théâtre";
  if (t.includes("danse") || t.includes("dance"))     return "Danse";
  if (t.includes("sport"))                            return "Sport";
  if (t.includes("exposition") || t.includes("expo")) return "Exposition";
  if (t.includes("opéra") || t.includes("opera"))     return "Opéra";
  if (t.includes("comédie") || t.includes("comedie")) return "Comédie";
  if (t.includes("cirque"))                           return "Cirque";
  return "Autre";
}

function mapTicketmasterCategory(segment = "", genre = "") {
  const s = (segment + " " + genre).toLowerCase();
  if (s.includes("music"))     return "Concert";
  if (s.includes("festival"))  return "Festival";
  if (s.includes("theatre") || s.includes("théâtre")) return "Théâtre";
  if (s.includes("dance") || s.includes("danse"))     return "Danse";
  if (s.includes("sport"))     return "Sport";
  if (s.includes("opera"))     return "Opéra";
  if (s.includes("comedy"))    return "Comédie";
  if (s.includes("arts"))      return "Exposition";
  return "Autre";
}

// ─── FORMATAGE DATE ───────────────────────────────────────────────────────────
function isoToFr(isoStr) {
  if (!isoStr) return "";
  try {
    const d = new Date(isoStr);
    const dd = String(d.getDate()).padStart(2, "0");
    const mm = String(d.getMonth() + 1).padStart(2, "0");
    const yyyy = d.getFullYear();
    return `${dd}/${mm}/${yyyy}`;
  } catch {
    return isoStr;
  }
}

function isoToTime(isoStr) {
  if (!isoStr) return "";
  try {
    const d = new Date(isoStr);
    return `${String(d.getHours()).padStart(2,"0")}:${String(d.getMinutes()).padStart(2,"0")}`;
  } catch {
    return "";
  }
}

// ─── UPSERT FIRESTORE ─────────────────────────────────────────────────────────
// Mise à jour si existant, création sinon — évite les doublons par sourceId
async function upsertEvent(data) {
  const q = await db.collection("events")
    .where("sourceId", "==", data.sourceId)
    .where("source",   "==", data.source)
    .limit(1)
    .get();

  if (!q.empty) {
    await q.docs[0].ref.update({ ...data, updatedAt: Timestamp.now() });
  } else {
    await db.collection("events").add({
      ...data,
      isActive:  true,
      featured:  false,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SYNC OPENAGENDA
// ═════════════════════════════════════════════════════════════════════════════
async function runSyncOpenAgenda() {
  const { apiKey, size, maxPages } = CONFIG.openagenda;
  let synced = 0;
  let after  = null;   // curseur de pagination OpenAgenda

  for (let page = 0; page < maxPages; page++) {
    const params = new URLSearchParams({
      key:   apiKey,
      size:  String(size),
      // Événements futurs uniquement
      "timings[gte]": new Date().toISOString().split("T")[0],
      // Trier par date croissante
      sort:  "timings.start",
    });
    if (after) params.set("after", after);

    const url = `https://api.openagenda.com/v2/events?${params}`;
    const res  = await fetch(url);
    if (!res.ok) {
      console.error(`OpenAgenda HTTP ${res.status}`);
      break;
    }
    const json = await res.json();
    const items = json.events || [];
    if (items.length === 0) break;

    for (const ev of items) {
      try {
        // Image : prendre la première disponible
        const imageUrl =
          ev.image?.base
            ? `${ev.image.base}${ev.image.filename}`
            : ev.thumbnail || "";

        // Coordonnées
        const lat = ev.location?.latitude  || 0;
        const lng = ev.location?.longitude || 0;

        // Dates
        const firstTiming = ev.timings?.[0] || {};
        const dateStr  = isoToFr(firstTiming.start);
        const dateEnd  = isoToFr(firstTiming.end);
        const timeStr  = isoToTime(firstTiming.start);

        // Tags → catégorie
        const tags = ev.keywords?.fr || ev.keywords?.en || [];
        const category = mapOpenAgendaCategory(
          Array.isArray(tags) ? tags : [tags]
        );

        // Lien billetterie
        const ticketUrl =
          ev.registration?.map(r => r.value).find(v => v?.startsWith("http")) ||
          ev.links?.find(l => l.type === "website")?.url || "";

        await upsertEvent({
          source:      "openagenda",
          sourceId:    String(ev.uid),
          title:       ev.title?.fr || ev.title?.en || "Sans titre",
          description: ev.description?.fr || ev.description?.en || "",
          location:    ev.location?.name || "",
          address:     ev.location?.address || "",
          city:        ev.location?.city || "",
          department:  ev.location?.department || "",
          region:      ev.location?.region || "",
          date:        dateStr,
          dateEnd:     dateEnd,
          time:        timeStr,
          category,
          imageUrl,
          ticketUrl,
          partnerName: "OpenAgenda",
          latitude:    lat,
          longitude:   lng,
        });
        synced++;
      } catch (err) {
        console.error("OpenAgenda item error:", err.message);
      }
    }

    // Pagination
    after = json.after;
    if (!after || items.length < size) break;
  }

  console.log(`✅ OpenAgenda : ${synced} événements synchronisés`);
  return synced;
}

// ═════════════════════════════════════════════════════════════════════════════
// SYNC TICKETMASTER
// ═════════════════════════════════════════════════════════════════════════════
async function runSyncTicketmaster() {
  const { apiKey, countryCode, size, maxPages } = CONFIG.ticketmaster;
  let synced = 0;
  const now  = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");

  for (let page = 0; page < maxPages; page++) {
    const params = new URLSearchParams({
      apikey:      apiKey,
      countryCode,
      size:        String(size),
      page:        String(page),
      sort:        "date,asc",
      startDateTime: now,
    });

    const url = `https://app.ticketmaster.com/discovery/v2/events.json?${params}`;
    const res  = await fetch(url);
    if (!res.ok) {
      console.error(`Ticketmaster HTTP ${res.status}`);
      break;
    }
    const json = await res.json();
    const items = json._embedded?.events || [];
    if (items.length === 0) break;

    for (const ev of items) {
      try {
        // Image HD en priorité
        const images = ev.images || [];
        const img =
          images.find(i => i.ratio === "16_9" && i.width >= 1024) ||
          images.find(i => i.ratio === "16_9") ||
          images[0];
        const imageUrl = img?.url || "";

        // Lieu
        const venue = ev._embedded?.venues?.[0] || {};
        const city  = venue.city?.name || "";
        const lat   = parseFloat(venue.location?.latitude  || "0");
        const lng   = parseFloat(venue.location?.longitude || "0");

        // Catégorie
        const segment = ev.classifications?.[0]?.segment?.name || "";
        const genre   = ev.classifications?.[0]?.genre?.name   || "";
        const category = mapTicketmasterCategory(segment, genre);

        // Dates
        const dateStr = isoToFr(ev.dates?.start?.localDate);
        const timeStr = ev.dates?.start?.localTime?.slice(0, 5) || "";

        // Lien billetterie
        const ticketUrl = ev.url || "";

        // Prix
        const priceRange = ev.priceRanges?.[0];
        const price = priceRange
          ? `${priceRange.min} - ${priceRange.max} ${priceRange.currency}`
          : "";

        await upsertEvent({
          source:      "ticketmaster",
          sourceId:    ev.id,
          title:       ev.name,
          description: ev.info || ev.pleaseNote || "",
          location:    venue.name || "",
          address:     venue.address?.line1 || "",
          city,
          department:  "",
          region:      "",
          date:        dateStr,
          dateEnd:     "",
          time:        timeStr,
          category,
          imageUrl,
          ticketUrl,
          partnerName: "Ticketmaster",
          latitude:    lat,
          longitude:   lng,
          price,
        });
        synced++;
      } catch (err) {
        console.error("Ticketmaster item error:", err.message);
      }
    }

    const totalPages = json.page?.totalPages || 1;
    if (page >= totalPages - 1) break;
  }

  console.log(`✅ Ticketmaster : ${synced} événements synchronisés`);
  return synced;
}

// ═════════════════════════════════════════════════════════════════════════════
// CLOUD FUNCTIONS EXPORTÉES
// ═════════════════════════════════════════════════════════════════════════════

// Sync planifiée toutes les 6h
export const syncOpenAgenda = onSchedule(
  {
    schedule:        "every 6 hours",
    region:          "europe-west1",
    timeoutSeconds:  300,
    memory:          "512MiB",
  },
  async () => { await runSyncOpenAgenda(); }
);

export const syncTicketmaster = onSchedule(
  {
    schedule:        "every 6 hours",
    region:          "europe-west1",
    timeoutSeconds:  300,
    memory:          "512MiB",
  },
  async () => { await runSyncTicketmaster(); }
);

// Trigger HTTP manuel — pour tester ou forcer une sync
// URL : https://europe-west1-[ton-projet].cloudfunctions.net/syncAllSources
export const syncAllSources = onRequest(
  { region: "europe-west1", timeoutSeconds: 540, memory: "512MiB" },
  async (req, res) => {
    try {
      const [oa, tm] = await Promise.all([
        runSyncOpenAgenda(),
        runSyncTicketmaster(),
      ]);
      res.json({ success: true, openagenda: oa, ticketmaster: tm });
    } catch (err) {
      console.error(err);
      res.status(500).json({ success: false, error: err.message });
    }
  }
);