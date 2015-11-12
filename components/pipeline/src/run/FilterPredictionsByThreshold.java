package run;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

public class FilterPredictionsByThreshold {
public static void main(String[] args) throws IOException {
  String predictionsFn = args[0];
  String paramsFn = args[1];
  
  Map<String, Double> relToMinScore = new HashMap<String, Double>();
  BufferedReader br = new BufferedReader(new FileReader(paramsFn));
  for (String line; (line = br.readLine()) != null;) {
    String rel = line.split(" ")[0];
    Double param = Double.parseDouble(line.split(" ")[1]);
    relToMinScore.put(rel, param);
  }
  br.close();
  br = new BufferedReader(new FileReader(predictionsFn));
  for (String line; (line = br.readLine()) != null;) {
    String[] parts = line.split("\t");

    String rel = parts[1];
    double score = Double.parseDouble(parts[8]);

    if (!relToMinScore.containsKey(rel)) {
      System.err.println("No score for: " + rel);
      continue;
    }
    
    if (score < relToMinScore.get(rel)) {
      continue;
    }
    System.out.println(line);
  }
  br.close();
}
}
