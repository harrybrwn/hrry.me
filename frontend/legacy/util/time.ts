export function millisecondsToStr(milliseconds: number) {
  const numberEnding = (n: number) => {
    return n > 1 ? "s" : "";
  };

  let temp = Math.floor(milliseconds / 1000);
  let years = Math.floor(temp / 31536000);
  if (years) {
    return years + " year" + numberEnding(years);
  }
  //TODO: Months! Maybe weeks?
  let days = Math.floor((temp %= 31536000) / 86400);
  if (days) {
    return days + " day" + numberEnding(days);
  }
  let hours = Math.floor((temp %= 86400) / 3600);
  if (hours) {
    return hours + " hour" + numberEnding(hours);
  }
  let minutes = Math.floor((temp %= 3600) / 60);
  if (minutes) {
    let seconds = temp % 60;
    return (
      minutes +
      " minute" +
      numberEnding(minutes) +
      ", " +
      seconds +
      " second" +
      numberEnding(seconds)
    );
  }
  let seconds = temp % 60;
  if (seconds) {
    return seconds + " second" + numberEnding(seconds);
  }
  return "less than a second";
}
