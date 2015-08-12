package run;

import util.TextIdentifier;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.HashMap;

/**
 * Created by beroth on 7/17/14.
 */
public class ConvertResponse2012To2015 {
  /**
   * This converts a response from 'pseudo' 2012 format into 2014 format.
   * The 'pseudo' 2012 format contains, instead of a bare document id, the
   * document_id + '.' + offset_annotation.
   * This offset annotation is then used to create the 2014 response.
   *
   * @param args
   * @throws java.io.IOException
   */

  public static String provenance2014(TextIdentifier tid) {
    int sentStart = tid.getSentenceStart();
    int sentEnd = tid.getSentenceEnd();
    int slotStart = tid.getFillerStart();
    int slotEnd = tid.getFillerEnd();

    // Provenance is indicated by a window of maximum size 150 characters.
    if (sentEnd - sentStart + 1 > 150) {
      // If sentence is longer than allowed, return a window of allowed size around slot.
      int slotLength = slotEnd - slotStart + 1;
      int halfWindow = (150 - slotLength) / 2;
      int provStart = Math.max(sentStart, slotStart - halfWindow);
      int provEnd = Math.min(sentEnd, slotEnd + halfWindow);
      return tid.getDocId() + ":" + provStart + "-" + provEnd;
    } else {
      return tid.getDocId() + ":" + sentStart + "-" + sentEnd;
    }
  }

  public static void main(String[] args) throws IOException {
    String relconfig = args[0];
    HashMap<String, String> relToArg2type = new HashMap<String, String>();
    BufferedReader br = new BufferedReader(new FileReader(relconfig));
    for (String line; (line = br.readLine()) != null;) {
      String[] parts = line.split(" ");
      if (line.trim().startsWith("#") || parts.length != 3) {
        continue;
      }
      if (parts[1].equals("arg2type")) {
        String rel = parts[0];
        String type = parts[2];
        relToArg2type.put(rel, type);
      }
    }
    br.close();

    br = new BufferedReader(new InputStreamReader(System.in));
    for (String line; (line = br.readLine()) != null;) {
      String[] parts = line.split("\t");
      if ("NIL".equals(parts[3])) {
        System.out.println(line);
      } else {

        String rel = parts[1];

        String arg2type;
        if (relToArg2type.containsKey(rel)) {
          arg2type = relToArg2type.get(rel);
        } else {
          System.err.println("No type configuration for relation: " + rel);
          arg2type = "";
        }

        //String[] docOffsets = parts[3].split(":");
        TextIdentifier tid = TextIdentifier.fromDelimited(parts[3]);
        System.out.println(
          parts[0] + "\t" + //1 query id
          rel + "\t" + //2 slot name
          parts[2] + "\t" + //3 run id
          provenance2014(tid) + "\t" + //4 provenance
          parts[4] + "\t" + //5 slot filler
          arg2type + "\t" + // 6 arg 2 type
          tid.getDocId() + ":" + tid.getFillerOffsets() + "\t" + //7 slot filler provenance TODO: get canonical mention
          parts[9] //8 score
        );
      }
    }
    br.close();
  }
}
