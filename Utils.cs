using System.Collections;
using System.Linq;
using Godot;

namespace SerbleNotes; 

public static class Utils {
	
	public static T WriteLine<T>(this T obj, string prefix = "") {
		string str = obj.ToString();
		
		// If its an array or a list, print each element on a new line
		if (obj is IEnumerable enumerable) {
			str = ArrayToString(enumerable);
		}
		
		//GD.Print(prefix + str);
		return obj;
	}
	
	public static string ArrayToString(IEnumerable array) {
		object[] objects = array.Cast<object>().ToArray();
		if (objects.Length == 0) {
			return "[]";
		}
		string result = objects.Aggregate("[", (current, o) => current + (o + ", "));
		return result[..^2] + "]";
	}
	
	
}
