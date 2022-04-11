// * Speech-Dispatcher server for emacspeak

//<copyright info

/* Tcl ViaVoiceOutloud Interface program
   (c) Copyright 1999 by Paige Phault

   The author hereby grants permission to use, copy, modify, distribute, and
   license this software for any purpose, provided that existing copyright
   notices
   are retained in all copies and that this notice is included verbatim in any
   distributions. No written agreement, license, or royalty fee is required for
   any of the authorized uses.  Modifications to this software may be
   copyrighted
   by their authors and need not follow the licensing terms described here,
   provided that the new terms are clearly indicated on the first page of each
   file where they apply.

   IN NO EVENT SHALL THE AUTHORS OR DISTRIBUTORS BE LIABLE TO ANY PARTY FOR
   DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
   OF THE USE OF THIS SOFTWARE, ITS DOCUMENTATION, OR ANY DERIVATIVES THEREOF,
   EVEN IF THE AUTHORS HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

   THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES, INCLUDING,
   BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
   PARTICULAR PURPOSE, AND NON-INFRINGEMENT.  THIS SOFTWARE IS PROVIDED ON AN
   "AS IS" BASIS, AND THE AUTHORS AND DISTRIBUTORS HAVE NO OBLIGATION TO PROVIDE
   MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
*/
//>
//<includes

#include <assert.h>
#include <libspeechd.h>
#include <iconv.h>
#include <set>
#include <stdlib.h>
#include <string.h>
#include <string>
#include <sys/time.h>
#include <tcl.h>
#include <vector>
using std::set;
using std::string;
using std::vector;

#define PACKAGENAME "tts"
#define PACKAGEVERSION "1.0"
#define EXPORT

//>
//<decls and function prototypes

SPDConnection *conn;

extern "C" EXPORT int Tclspeechd_Init(Tcl_Interp *interp);

int SetRate(ClientData, Tcl_Interp *, int, Tcl_Obj *CONST[]);
int GetRate(ClientData, Tcl_Interp *, int, Tcl_Obj *CONST[]);
int getTTSVersion(ClientData, Tcl_Interp *, int, Tcl_Obj *CONST[]);
int Punct(ClientData, Tcl_Interp *, int, Tcl_Obj *CONST[]);
int Say(ClientData, Tcl_Interp *, int, Tcl_Obj *CONST[]);
int SetLanguage(ClientData, Tcl_Interp *, int, Tcl_Obj *CONST[]);
int Stop(ClientData, Tcl_Interp *, int, Tcl_Obj *CONST[]);
int SpeakingP(ClientData, Tcl_Interp *, int, Tcl_Obj *CONST[]);
int Synchronize(ClientData, Tcl_Interp *, int, Tcl_Obj *CONST[]);
int Pause(ClientData, Tcl_Interp *, int, Tcl_Obj *CONST[]);
int Resume(ClientData, Tcl_Interp *, int, Tcl_Obj *CONST[]);

static int initLanguage(Tcl_Interp *interp);
static int getLangIndex(Tcl_Interp *interp, unsigned long *theIndex);

//>
//<TclSpeechdFree

void TclSpeechdFree(ClientData handle) {
  spd_close(conn);
}

//>
//<Tclspeechd_init

int Tclspeechd_Init(Tcl_Interp *interp) {
  void *handle = NULL;
  //<setup package, create tts handle

  if (Tcl_PkgProvide(interp, PACKAGENAME, PACKAGEVERSION) != TCL_OK) {
    Tcl_AppendResult(interp, "Error loading ", PACKAGENAME, NULL);
    return TCL_ERROR;
  }
  conn = spd_open("emacspeak", "tclspeechd", NULL, SPD_MODE_SINGLE);
  if (conn == 0) {
    Tcl_AppendResult(interp, "ERROR! Can't connect to Speech Dispatcher!", NULL);
    return TCL_ERROR;
  }

  spd_set_capital_letters(conn, SPD_CAP_NONE);

  spd_set_data_mode(conn, SPD_DATA_SSML);
  //>
  //<register tcl commands

  Tcl_CreateObjCommand(interp, "setRate", SetRate, (ClientData)handle,
                       TclSpeechdFree);
  Tcl_CreateObjCommand(interp, "getRate", GetRate, (ClientData)handle,
                       TclSpeechdFree);
  Tcl_CreateObjCommand(interp, "ttsVersion", getTTSVersion, (ClientData)handle,
                       TclSpeechdFree);
  Tcl_CreateObjCommand(interp, "punct", Punct, (ClientData)handle, NULL);
  Tcl_CreateObjCommand(interp, "say", Say, (ClientData)handle, TclSpeechdFree);
  Tcl_CreateObjCommand(interp, "synth", Say, (ClientData)handle, NULL);
  Tcl_CreateObjCommand(interp, "synchronize", Synchronize, (ClientData)handle,
                       TclSpeechdFree);
  Tcl_CreateObjCommand(interp, "stop", Stop, (ClientData)handle, TclSpeechdFree);
  Tcl_CreateObjCommand(interp, "speakingP", SpeakingP, (ClientData)handle,
                       TclSpeechdFree);
  Tcl_CreateObjCommand(interp, "pause", Pause, (ClientData)handle,
                       TclSpeechdFree);
  Tcl_CreateObjCommand(interp, "resume", Resume, (ClientData)handle,
                       TclSpeechdFree);
  Tcl_CreateObjCommand(interp, "setLanguage", SetLanguage, (ClientData)handle,
                       TclSpeechdFree);
  //>

  return initLanguage(interp);
}

int GetRate(ClientData handle, Tcl_Interp *interp, int objc,
            Tcl_Obj *CONST objv[]) {
  int rc, rate, voice;
  if (objc != 2) {
    Tcl_AppendResult(interp, "Usage: getRate voiceCode  ", TCL_STATIC);
    return TCL_ERROR;
  }
  rc = Tcl_GetIntFromObj(interp, objv[1], &voice);
  if (rc != TCL_OK)
    return rc;

  rate = spd_get_voice_rate(conn);

  Tcl_SetObjResult(interp, Tcl_NewIntObj(rate));
  return TCL_OK;
}

int SetRate(ClientData handle, Tcl_Interp *interp, int objc,
            Tcl_Obj *CONST objv[]) {
  static int current_rate = -1;
  int rc, rate, voice;
  int success = 1;
  if (objc != 3) {
    Tcl_AppendResult(interp, "Usage: setRate voiceCode speechRate ",
                     TCL_STATIC);
    return TCL_ERROR;
  }
  rc = Tcl_GetIntFromObj(interp, objv[1], &voice);
  if (rc != TCL_OK)
    return rc;
  rc = Tcl_GetIntFromObj(interp, objv[2], &rate);
  if (rc != TCL_OK)
    return rc;

  if (rate != current_rate) {
    success = (spd_set_voice_rate(conn, rate) != -1);
    if (success)
      current_rate = rate;
  }
  return success ? TCL_OK : TCL_ERROR;
}

//>
//<say

static string::size_type findInRange(const char c, const string &str,
                                     string::size_type start,
                                     string::size_type end) {
  if (end >= str.size()) {
    end = str.size();
  }
  for (string::size_type i = start; i < end; ++i) {
    if (c == str[i]) {
      return i;
    }
  }
  return string::npos;
}

static bool closeTags(string &ssml) {
  // check that a text (non whitespace) is present
  int a_tag_count = 0;
  bool a_text_is_present = false;

  for (auto tag = ssml.cbegin(); tag != ssml.cend(); ++tag) {
    if (*tag == '<') {
      a_tag_count++;
    }
    if ((a_tag_count == 0) && (*tag != ' ') && (*tag != '\n') &&
        (*tag != '\r') && (*tag != '\t')) {
      a_text_is_present = true;
      break;
    }
    if ((*tag == '>') && a_tag_count) {
      a_tag_count--;
    }
  }

  if (a_text_is_present) {
    string::size_type tag_pos = ssml.size();
    if (string::npos == tag_pos) {
      fprintf(stderr, "Synthesizer argument of size (size_t)(-1), ignoring "
                      "last character\n");
      --tag_pos;
    }
    string::size_type prev_match = tag_pos;
    while (string::npos != tag_pos) {
      // look for a '<'
      tag_pos = ssml.find_last_of('<', tag_pos);
      if (string::npos != tag_pos) {
        string::size_type end = findInRange(' ', ssml, tag_pos, prev_match);
        if ((string::npos == end) &&
            (string::npos == findInRange('/', ssml, tag_pos, prev_match))) {
          end = findInRange('>', ssml, tag_pos, prev_match);
        }
        if ((string::npos != end) && (tag_pos + 1 < end)) {
          ssml.append("</");
          ssml.append(ssml.substr(tag_pos + 1, end - (tag_pos + 1)));
          ssml.push_back('>');
        }
        prev_match = tag_pos;
        tag_pos--; // Start search before previous tag to avoid infinite loop
      }
    }
  }
  return a_text_is_present;
}

int Say(ClientData handle, Tcl_Interp *interp, int objc,
        Tcl_Obj *CONST objv[]) {
  int i;
  for (i = 1; i < objc; i++) {
    char *a_text = (char *)Tcl_GetStringFromObj(objv[i], NULL);
    if (a_text) {
      string a_ssml = a_text;
      if (closeTags(a_ssml)) {
        a_ssml = "<speak>" + a_ssml + "</speak>";
        if (spd_say(conn, SPD_MESSAGE, a_ssml.c_str()) == -1) {
          Tcl_AppendResult(
              interp, "Could not synthesize string: ", a_ssml.c_str());
          return TCL_ERROR;
        }
      }
    }
  }
  return TCL_OK;
}

//>
//<stop, pause, resume

//<synchronize, stop

int Synchronize(ClientData handle, Tcl_Interp *interp, int objc,
                Tcl_Obj *CONST objv[]) {
  return TCL_OK;
}

int Stop(ClientData handle, Tcl_Interp *interp, int objc,
         Tcl_Obj *CONST objv[]) {
  spd_cancel(conn);
  return TCL_OK;
}

//>

int SpeakingP(ClientData handle, Tcl_Interp *interp, int objc,
              Tcl_Obj *CONST objv[]) {
  Tcl_SetObjResult(interp, Tcl_NewIntObj(0));
  return TCL_OK;
}

int Pause(ClientData handle, Tcl_Interp *interp, int objc,
          Tcl_Obj *CONST objv[]) {
  spd_pause(conn);
  return TCL_OK;
}

int Resume(ClientData handle, Tcl_Interp *interp, int objc,
           Tcl_Obj *CONST objv[]) {
  spd_resume(conn);
  return TCL_OK;
}

//>
//<setOutput:NoOp

int setOutput(ClientData handle, Tcl_Interp *interp, int objc,
              Tcl_Obj *CONST objv[]) {
  return TCL_OK;
}

//>
//< Punct

int Punct(ClientData handle, Tcl_Interp *interp, int objc,
          Tcl_Obj *CONST objv[]) {
  char *a_mode = (char *)Tcl_GetStringFromObj(objv[1], NULL);
  static const char *current_mode = "";
  if (a_mode && strcmp(a_mode, current_mode)) {
    SPDPunctuation a_type = SPD_PUNCT_NONE;

    if (strcmp(a_mode, "none") == 0) {
      a_type = SPD_PUNCT_NONE;
      current_mode = "none";
    } else if (strcmp(a_mode, "all") == 0) {
      a_type = SPD_PUNCT_ALL;
      current_mode = "all";
    } else if (strcmp(a_mode, "some") == 0) {
      a_type = SPD_PUNCT_SOME;
      current_mode = "some";
    }

    spd_set_punctuation(conn, a_type);
  }
  return TCL_OK;
}

//>
//<getVersion

int getTTSVersion(ClientData handle, Tcl_Interp *interp, int objc,
                  Tcl_Obj *CONST objv[]) {
  if (objc != 1) {
    Tcl_AppendResult(interp, "Usage: ttsVersion   ", TCL_STATIC);
    return TCL_ERROR;
  }

  char *version = new char[16];
  snprintf(version, 16, "%d.%d", LIBSPEECHD_MAJOR_VERSION, LIBSPEECHD_MINOR_VERSION);
  Tcl_SetResult(interp, version, TCL_STATIC);
  return TCL_OK;
}

//>
//<SetLanguage

static vector<string> available_languages;

static int SetLanguageHelper(Tcl_Interp *interp, size_t aIndex) {
  int voice_status = spd_set_language(conn, (char *)available_languages[aIndex].c_str());
  if (voice_status == -1) {
    Tcl_AppendResult(interp, "could not set voice");
    return TCL_ERROR;
  }
  return TCL_OK;
}

int SetLanguage(ClientData eciHandle, Tcl_Interp *interp, int objc,
                Tcl_Obj *CONST objv[]) {
  unsigned long aIndex = 0;

  if (getLangIndex(interp, &aIndex)) {
    return SetLanguageHelper(interp, aIndex);
  }
  // TODO: Error reporting for this
  return TCL_OK;
}

//>
//<initLanguage, getLangIndex

static int initLanguage(Tcl_Interp *interp) {
  // List the available languages
  set<string> unique_languages;
  int i = 0;
  unsigned long ui = 0;
  char *envDefaultLang = (char *)getenv("LANGUAGE");
  if (envDefaultLang == NULL) {
    envDefaultLang = (char *)getenv("LANG");
    if (envDefaultLang == NULL) {
      envDefaultLang = (char *)"en";
    }
  }
  string aDefaultLang = envDefaultLang;
  size_t remove = std::min(aDefaultLang.find('.', 0), aDefaultLang.find(':', 0));

  // Snip off everything following a period.  So en-us.utf8 becomes en-us.
  if (remove != string::npos) {
    aDefaultLang.erase(aDefaultLang.begin() + remove, aDefaultLang.end());
  }
  // And replace _ with -, E.G. en_US becomes en-US.
  for (string::iterator it = aDefaultLang.begin(); it != aDefaultLang.end();
       it++) {
    if (*it == '_') {
      *it = '-';
    }
  }

  SPDVoice **voices = spd_list_synthesis_voices(conn);

  for (i = 0; voices[i] != 0; i++) {
    string voice_lang = voices[i]->language;
    unique_languages.insert(voice_lang);
  }
  available_languages.assign(unique_languages.begin(), unique_languages.end());
  vector<string>::iterator it;
  size_t lang_count = available_languages.size();
  size_t english_index = lang_count;
  size_t default_index = lang_count;
  char buffer[256];
  for (ui = 0; ui < lang_count; ui++) {
    const char *aLangCode = available_languages[ui].c_str();
    snprintf(buffer, sizeof(buffer), "%lu", ui);
    Tcl_SetVar2(interp, "langalias", aLangCode, buffer, 0);
    Tcl_SetVar2(interp, "langcode", buffer, aLangCode, 0);
    if (default_index == lang_count) {
      if (strcasecmp(aDefaultLang.c_str(), aLangCode) == 0) {
        Tcl_SetVar2(interp, "langsynth", "current", buffer, 0);
        Tcl_SetVar2(interp, "langcode", "current", (char *)aLangCode, 0);
        default_index = ui;
      }
    }
    if (strcmp(aLangCode, "en") == 0) {
      english_index = ui;
    }
  }
  if ((default_index == lang_count) && (english_index == lang_count)) {
    fprintf(stderr, "Could not find your default language, and English\n");
    fprintf(stderr, "doesn't seem to be available either.  Bailing now.\n");
    exit(1);
  }
  if (default_index == lang_count) {
    default_index = english_index;
    fprintf(stderr, "Couldn't find your default language, using English.\n");
    snprintf(buffer, sizeof(buffer), "%lu", english_index);
    Tcl_SetVar2(interp, "langsynth", "current", buffer, 0);
    Tcl_SetVar2(interp, "langcode", "current", "en", 0);
  }

  if (TCL_OK != SetLanguageHelper(interp, default_index)) {
    return TCL_ERROR;
  }
  // Presumably we have at least one language, namely English,
  // so no chance of underflowing size_t with this subtraction:
  snprintf(buffer, sizeof(buffer), "%lu", lang_count - 1);
  Tcl_SetVar2(interp, "langsynth", "top", buffer, 0);
  return TCL_OK;
}

static int getLangIndex(Tcl_Interp *interp, unsigned long *theIndex) {
  int aStatus = 0;
  const char *aInfo = Tcl_GetVar2(interp, "langsynth", "current", 0);
  char *end = NULL;
  if (aInfo) {
    *theIndex = strtoul(aInfo, &end, 10);

    if (end && !*end) {
      if ((*theIndex > 0) && (*theIndex < available_languages.size())) {
        aStatus = 1;
      }
    }
  }
  return aStatus;
}

//>
//<end of file
// local variables:
// folded-file: t
// end:
//>
